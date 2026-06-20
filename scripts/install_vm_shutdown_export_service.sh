#!/usr/bin/env bash
set -euo pipefail

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

if [[ -z "$PROJECT_DIR" ]]; then
  echo "Project directory not found" >&2
  exit 1
fi

cat > /etc/systemd/system/kafka-monitoring-gcs-export.service <<EOF
[Unit]
Description=Export Kafka monitoring PostgreSQL snapshots to GCS before shutdown
After=docker.service network-online.target
Requires=docker.service
Before=shutdown.target reboot.target halt.target
DefaultDependencies=no

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/true
ExecStop=$PROJECT_DIR/scripts/export_vm_postgres_to_gcs.sh
TimeoutStopSec=180

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kafka-monitoring-gcs-export.service
systemctl restart kafka-monitoring-gcs-export.service
systemctl status kafka-monitoring-gcs-export.service --no-pager
