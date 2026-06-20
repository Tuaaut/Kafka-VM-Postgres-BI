# LINE Official Account Alerting

This file records the first LINE Official Account setup for this project. It is intentionally reusable so future projects can copy the pattern without starting from zero.

## Current Status

LINE alerting has been prepared and tested with the LINE Messaging API.

Confirmed:

```text
LINE Official Account created: Kafka Alert Bot
Basic ID: @658ndqox
Provider: Kafka Monitoring Demo
Channel ID: 2010459362
Messaging API: enabled
Send mode used for first test: broadcast
Real LINE API test result: HTTP 200
```

Secret handling:

```text
LINE channel access token: stored only in local .env
LINE channel secret: not required for current broadcast test
Markdown docs: must not contain LINE tokens or secrets
Git: .env is ignored
```

## Why LINE Was Added

The project now uses a two-channel alerting design:

```text
Gmail = official searchable alert record
LINE = fast mobile response channel
```

Gmail is better for history, filtering, and audit evidence. LINE is better for immediate attention from technicians or operations users.

## Current Implementation

Prepared flow:

```text
Grafana alert rule
-> Grafana webhook contact point
-> LINE alert bridge
-> LINE Messaging API
-> LINE Official Account audience
```

Current tested direct flow:

```text
scripts/test_line_alert.sh
-> alerting/line_alert_bridge.py
-> LINE Messaging API broadcast endpoint
-> Kafka Alert Bot followers
```

The bridge supports two send modes:

| Mode | Required values | Use case |
| --- | --- | --- |
| `broadcast` | `LINE_CHANNEL_ACCESS_TOKEN` | Send to all friends/followers of the LINE Official Account. Good for first MVP test. |
| `push` | `LINE_CHANNEL_ACCESS_TOKEN`, `LINE_TO_ID` | Send to one user, group, or room. Better for a real operations group chat later. |

Current local `.env` uses:

```text
LINE_SEND_MODE=broadcast
LINE_MIN_SEVERITY=critical
LINE_DISABLE_RESOLVED=true
```

## Files Added

```text
alerting/line_alert_bridge.py
scripts/configure_line_alerts.sh
scripts/run_line_bridge_local.sh
scripts/test_line_alert.sh
grafana/provisioning/alerting/line_webhook_contact_point.yml
docs/line_official_account_alerting.md
```

## Bridge Endpoints

The local bridge exposes:

```text
GET  /health
POST /grafana
POST /line/webhook
```

Endpoint purposes:

| Endpoint | Purpose |
| --- | --- |
| `/health` | Basic health check for local, VM, or Cloud Run deployment. |
| `/grafana` | Receives Grafana webhook payloads, formats an operations-friendly LINE message, and sends it through LINE. |
| `/line/webhook` | Captures LINE webhook source IDs such as `userId`, `groupId`, or `roomId` for future push-mode targeting. |

## Message Format

The LINE message is intentionally short and operational:

```text
[Kafka Monitoring Alert]
Status: FIRING
Alert: Plant State Critical
Severity: critical

Summary: Plant state is critical.
Impact: Production monitoring has detected a critical condition in the recent machine event window.
Action plan:
1. Open the Grafana control-room dashboard and confirm the Plant State panel.
2. Check the latest alert feed to identify the affected production line, machine, and reason.
3. Notify the responsible technician or production support owner to inspect the line and take action as soon as possible.
4. Keep the incident open until the dashboard returns to NORMAL or the root cause is confirmed.

Dashboard: http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room

Gmail remains the official searchable alert record.
```

## Local Test

Run:

```bash
scripts/test_line_alert.sh
```

Expected successful result:

```json
{
  "sent": true,
  "status": 200,
  "response": "{}"
}
```

This confirms:

```text
The LINE channel access token works.
The LINE Messaging API accepted the request.
The bridge can format and send the alert message.
```

It does not yet prove Grafana webhook routing end to end, because the Grafana LINE contact point is prepared but not routed in the notification policy yet.

## Local Bridge Run

Start the bridge:

```bash
scripts/run_line_bridge_local.sh
```

Health check:

```bash
curl http://localhost:8080/health
```

Expected:

```json
{
  "status": "ok"
}
```

Docker Compose bridge option:

```bash
docker compose --profile line-alerts up -d line-alert-bridge
```

## Grafana Contact Point

Prepared contact point:

```text
Name: kafka-line-webhook
Type: webhook
File: grafana/provisioning/alerting/line_webhook_contact_point.yml
URL env var: LINE_ALERT_WEBHOOK_URL
Resolved messages: disabled
```

Default local Docker URL:

```text
LINE_ALERT_WEBHOOK_URL=http://line-alert-bridge:8080/grafana
```

Current routing status:

```text
Not routed yet
```

Reason:

```text
The bridge needs a stable runtime first. For local Docker this can be the line-alert-bridge profile. For production it can run on the GCP VM or Cloud Run.
```

## Cost Control

Keep LINE low-volume:

```text
LINE_MIN_SEVERITY=critical
LINE_DISABLE_RESOLVED=true
```

Reason:

```text
LINE message usage depends on how many people receive messages. A small test audience is low risk. Large broadcast audiences can consume quota quickly.
```

Operational recommendation:

```text
Send CRITICAL alerts to LINE.
Keep WARNING alerts in Grafana and Gmail until alert volume is stable.
Keep resolved LINE messages disabled unless the team explicitly needs them.
```

## Reusable Parts

These parts can be reused in other projects:

- LINE Official Account creation pattern.
- LINE Messaging API channel setup.
- Long-lived channel access token stored in local `.env`.
- `broadcast` mode for a quick MVP alert channel.
- `push` mode design for user, group, or room targeting.
- `/line/webhook` source ID capture pattern.
- `LINE_MIN_SEVERITY` and `LINE_DISABLE_RESOLVED` controls.
- Bridge shape: receive a webhook, format the message, send to LINE.
- Secret rule: never write access tokens into Markdown or Git.

Reusable files:

```text
alerting/line_alert_bridge.py
scripts/configure_line_alerts.sh
scripts/run_line_bridge_local.sh
scripts/test_line_alert.sh
```

When copying to another project, change the alert text, dashboard URL, severity labels, and environment variable names only if the receiving project needs different names.

## Project-Specific Parts

These values belong to this Kafka monitoring project:

```text
Official Account name: Kafka Alert Bot
Basic ID: @658ndqox
Provider name: Kafka Monitoring Demo
Channel ID: 2010459362
Grafana dashboard URL: http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room
Alert name: Plant State Critical
Project label: kafka_vm_postgres_bi
Operations wording: production line, machine, technician, control-room dashboard
```

These should be changed when reusing the setup elsewhere:

```text
Official Account name
Provider/channel if creating a separate LINE OA
Dashboard URL
Alert names
Message summary and action plan
Severity routing
Target audience
```

## Broadcast vs Group Chat

Current working mode:

```text
broadcast to LINE Official Account friends
```

This is enough for a portfolio MVP and one-person testing.

Future group-chat mode:

```text
push to groupId
```

To enable true group chat later:

1. Enable "Allow bot to join group chats" in LINE Official Account Manager.
2. Add `Kafka Alert Bot` to the LINE group.
3. Run the bridge with a public `/line/webhook` URL.
4. Configure the LINE channel webhook URL to that public bridge URL.
5. Send a message in the group.
6. Read the bridge log and capture `groupId`.
7. Save `LINE_TO_ID=<groupId>` in `.env`.
8. Set `LINE_SEND_MODE=push`.
9. Test with `scripts/test_line_alert.sh`.
10. Route Grafana critical alerts to `kafka-line-webhook`.

## Production Runtime Options

Option 1: Run bridge on the same GCP VM.

```text
Lowest moving parts
No separate Cloud Run service
Good for this small demo
```

Option 2: Run bridge on Cloud Run.

```text
Cleaner public webhook endpoint
Better separation from Grafana VM
Useful for portfolio integration story
Small extra cost risk if alert volume is high
```

Option 3: Keep local/manual test only.

```text
Useful for proof of concept
Not suitable for production alerts
```

Recommended next step for this project:

```text
Use broadcast mode for MVP.
Route only CRITICAL Grafana alerts to LINE after deciding where the bridge should run.
Move to group push mode later if the project needs a real team chat demonstration.
```

## Security Checklist

- Do not commit `.env`.
- Do not paste LINE access tokens into Markdown.
- Do not screenshot tokens for documentation.
- Reissue the LINE channel access token if it is exposed.
- Keep `LINE_CHANNEL_SECRET` only in `.env` or the production secret store if webhook signature validation is enabled.
- Use separate LINE channels/accounts for unrelated public projects if alert audiences should be separated.
