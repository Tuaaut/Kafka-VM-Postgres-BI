#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  docker exec -it kafka_vm_postgres psql -U monitoring_user -d machine_monitoring
else
  docker exec -i kafka_vm_postgres psql -U monitoring_user -d machine_monitoring -c "$*"
fi
