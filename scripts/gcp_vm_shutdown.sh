#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/kafka-monitoring-shutdown.log"
PROJECT_DIR="${PROJECT_DIR:-}"

if [[ -z "$PROJECT_DIR" ]]; then
  for candidate in \
    /home/*/Kafka-VM-Postgres-BI \
    /root/Kafka-VM-Postgres-BI \
    /opt/Kafka-VM-Postgres-BI
  do
    if [[ -d "$candidate" ]]; then
      PROJECT_DIR="$candidate"
      break
    fi
  done
fi

{
  echo "==== $(date -Iseconds) Kafka monitoring shutdown export ===="
  if systemctl is-enabled kafka-monitoring-gcs-export.service >/dev/null 2>&1; then
    echo "Systemd service kafka-monitoring-gcs-export.service handles the pre-Docker export."
  elif [[ -n "$PROJECT_DIR" && -x "$PROJECT_DIR/scripts/export_vm_postgres_to_gcs.sh" ]]; then
    PROJECT_DIR="$PROJECT_DIR" "$PROJECT_DIR/scripts/export_vm_postgres_to_gcs.sh"
  else
    echo "Export script not found or not executable: $PROJECT_DIR/scripts/export_vm_postgres_to_gcs.sh"
  fi
} >> "$LOG_FILE" 2>&1 || true
