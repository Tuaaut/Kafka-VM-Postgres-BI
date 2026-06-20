import base64
import hashlib
import hmac
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


LINE_PUSH_URL = "https://api.line.me/v2/bot/message/push"
LINE_BROADCAST_URL = "https://api.line.me/v2/bot/message/broadcast"
MAX_LINE_TEXT_LENGTH = 5000


def env_bool(name, default=False):
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


def severity_rank(severity):
    return {
        "critical": 3,
        "warning": 2,
        "info": 1,
    }.get(str(severity or "").lower(), 0)


def should_send_alert(alert, status):
    if status == "resolved" and env_bool("LINE_DISABLE_RESOLVED", True):
        return False

    min_severity = os.getenv("LINE_MIN_SEVERITY", "critical").lower()
    severity = alert.get("labels", {}).get("severity", "")
    return severity_rank(severity) >= severity_rank(min_severity)


def truncate_text(text, limit=MAX_LINE_TEXT_LENGTH):
    if len(text) <= limit:
        return text
    return text[: limit - 120].rstrip() + "\n\n...message truncated. Open Grafana for full details."


def format_grafana_alert(payload):
    status = str(payload.get("status") or "firing").upper()
    group_labels = payload.get("groupLabels") or {}
    common_labels = payload.get("commonLabels") or {}
    alerts = payload.get("alerts") or []

    title = group_labels.get("alertname") or common_labels.get("alertname") or "Grafana Alert"
    severity = group_labels.get("severity") or common_labels.get("severity") or "unknown"

    lines = [
        "[Kafka Monitoring Alert]",
        f"Status: {status}",
        f"Alert: {title}",
        f"Severity: {severity}",
        "",
    ]

    included = 0
    for alert in alerts:
        alert_status = str(alert.get("status") or payload.get("status") or "firing").lower()
        if not should_send_alert(alert, alert_status):
            continue

        labels = alert.get("labels") or {}
        annotations = alert.get("annotations") or {}
        dashboard_url = alert.get("dashboardURL") or payload.get("externalURL") or os.getenv("GRAFANA_ROOT_URL", "")

        included += 1
        lines.extend(
            [
                f"Summary: {annotations.get('summary', labels.get('alertname', title))}",
                f"Impact: {annotations.get('impact', 'Production monitoring needs attention.')}",
                "Action plan:",
                annotations.get(
                    "action_plan",
                    "1. Open Grafana.\n2. Identify the affected line or machine.\n3. Notify the responsible technician.",
                ),
            ]
        )
        if dashboard_url:
            lines.extend(["", f"Dashboard: {dashboard_url}"])
        lines.append("")

    if included == 0:
        return None

    lines.append("Gmail remains the official searchable alert record.")
    return truncate_text("\n".join(lines).strip())


def send_line_message(text):
    token = os.getenv("LINE_CHANNEL_ACCESS_TOKEN", "").strip()
    to_id = os.getenv("LINE_TO_ID", "").strip()
    send_mode = os.getenv("LINE_SEND_MODE", "push").strip().lower()

    if send_mode not in {"push", "broadcast"}:
        return {
            "sent": False,
            "dry_run": True,
            "reason": "LINE_SEND_MODE must be push or broadcast",
            "message": text,
        }

    if not token:
        return {
            "sent": False,
            "dry_run": True,
            "reason": "LINE_CHANNEL_ACCESS_TOKEN is not set",
            "message": text,
        }

    if send_mode == "push":
        if not to_id:
            return {
                "sent": False,
                "dry_run": True,
                "reason": "LINE_TO_ID is not set for push mode",
                "message": text,
            }
        url = LINE_PUSH_URL
        payload = {"to": to_id, "messages": [{"type": "text", "text": text}]}
    else:
        url = LINE_BROADCAST_URL
        payload = {"messages": [{"type": "text", "text": text}]}

    body = json.dumps(payload).encode("utf-8")
    request = Request(
        url,
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(request, timeout=20) as response:
            response_body = response.read().decode("utf-8")
            return {"sent": True, "status": response.status, "response": response_body}
    except HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        return {"sent": False, "status": error.code, "error": error_body}
    except URLError as error:
        return {"sent": False, "error": str(error)}


def valid_line_signature(body, signature):
    secret = os.getenv("LINE_CHANNEL_SECRET", "").strip()
    if not secret:
        return True
    digest = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).digest()
    expected = base64.b64encode(digest).decode("utf-8")
    return hmac.compare_digest(expected, signature or "")


class Handler(BaseHTTPRequestHandler):
    def write_json(self, status, payload):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_json(self):
        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length)
        if not body:
            return body, {}
        return body, json.loads(body.decode("utf-8"))

    def do_GET(self):
        if self.path == "/health":
            self.write_json(200, {"status": "ok"})
            return
        self.write_json(404, {"error": "not found"})

    def do_POST(self):
        try:
            body, payload = self.read_json()
        except json.JSONDecodeError:
            self.write_json(400, {"error": "invalid JSON"})
            return

        if self.path == "/grafana":
            text = format_grafana_alert(payload)
            if text is None:
                self.write_json(200, {"sent": False, "reason": "no alert matched LINE routing rules"})
                return
            result = send_line_message(text)
            self.write_json(200 if result.get("sent") or result.get("dry_run") else 502, result)
            return

        if self.path == "/line/webhook":
            if not valid_line_signature(body, self.headers.get("X-Line-Signature")):
                self.write_json(403, {"error": "invalid LINE signature"})
                return
            sources = []
            for event in payload.get("events", []):
                source = event.get("source", {})
                sources.append(
                    {
                        "type": source.get("type"),
                        "userId": source.get("userId"),
                        "groupId": source.get("groupId"),
                        "roomId": source.get("roomId"),
                    }
                )
            print(json.dumps({"line_webhook_sources": sources}, indent=2), flush=True)
            self.write_json(200, {"ok": True, "sources": sources})
            return

        self.write_json(404, {"error": "not found"})


def main():
    port = int(os.getenv("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"LINE alert bridge listening on port {port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
