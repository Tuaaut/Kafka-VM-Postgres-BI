#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -f .env ]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    export "$key=$value"
  done < .env
fi

python3 - <<'PY'
import json
import os
import sys

sys.path.insert(0, "alerting")
from line_alert_bridge import format_grafana_alert, send_line_message

payload = {
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
                "impact": "Production monitoring has detected a critical condition in the recent machine event window.",
                "action_plan": (
                    "1. Open the Grafana control-room dashboard and confirm the Plant State panel.\n"
                    "2. Check the latest alert feed to identify the affected production line, machine, and reason.\n"
                    "3. Notify the responsible technician or production support owner to inspect the line and take action as soon as possible.\n"
                    "4. Keep the incident open until the dashboard returns to NORMAL or the root cause is confirmed."
                ),
            },
            "dashboardURL": os.getenv(
                "GRAFANA_DASHBOARD_URL",
                "http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room",
            ),
        }
    ],
}

message = format_grafana_alert(payload)
result = send_line_message(message)
print(json.dumps(result, indent=2))
PY
