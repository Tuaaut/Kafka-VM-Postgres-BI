#!/usr/bin/env bash
set -euo pipefail

docker exec -i kafka_vm_postgres psql \
  -U monitoring_user \
  -d machine_monitoring \
  -c "SELECT * FROM dashboard_realtime_summary;" \
  -c "SELECT event_type, status, COUNT(*) FROM machine_events_raw GROUP BY event_type, status ORDER BY 3 DESC;"
