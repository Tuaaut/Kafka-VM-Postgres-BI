#!/usr/bin/env bash
set -euo pipefail

docker exec -i kafka_vm_postgres psql \
  -U monitoring_user \
  -d machine_monitoring \
  -c "TRUNCATE TABLE machine_events_raw;"
