"""Send one sample Grafana-shaped alert through the LINE bridge.

Extracted from a heredoc that used to live in scripts/test_line_alert.sh so
that the PowerShell and shell entry points run the same code, and so this is
editable and lintable like any other file.
"""

import json
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "alerting"))

from line_alert_bridge import format_grafana_alert, send_line_message  # noqa: E402

DEFAULT_DASHBOARD_URL = (
    "http://136.110.54.120:3000/d/kafka-machine-monitoring"
    "/kafka-machine-monitoring-control-room"
)

ACTION_PLAN = (
    "1. Open the Grafana control-room dashboard and confirm the Plant State panel.\n"
    "2. Check the latest alert feed to identify the affected production line, "
    "machine, and reason.\n"
    "3. Notify the responsible technician or production support owner to inspect "
    "the line and take action as soon as possible.\n"
    "4. Keep the incident open until the dashboard returns to NORMAL or the root "
    "cause is confirmed."
)


def build_payload() -> dict:
    return {
        "status": "firing",
        "groupLabels": {
            "alertname": "Plant State Critical",
            "severity": "critical",
        },
        "commonLabels": {
            "project": "kafka_vm_postgres_bi",
        },
        "alerts": [
            {
                "status": "firing",
                "labels": {
                    "alertname": "Plant State Critical",
                    "severity": "critical",
                },
                "annotations": {
                    "summary": "Plant state is critical.",
                    "impact": (
                        "Production monitoring has detected a critical condition "
                        "in the recent machine event window."
                    ),
                    "action_plan": ACTION_PLAN,
                },
                "dashboardURL": os.getenv(
                    "GRAFANA_DASHBOARD_URL", DEFAULT_DASHBOARD_URL
                ),
            }
        ],
    }


def main() -> int:
    message = format_grafana_alert(build_payload())
    result = send_line_message(message)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
