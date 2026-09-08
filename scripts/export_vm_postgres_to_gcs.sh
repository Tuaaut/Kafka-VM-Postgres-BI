#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-}"
if [[ -z "$PROJECT_DIR" ]]; then
  if [[ -n "${HOME:-}" && -d "$HOME/Kafka-VM-Postgres-BI" ]]; then
    PROJECT_DIR="$HOME/Kafka-VM-Postgres-BI"
  else
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
fi

if [[ -z "$PROJECT_DIR" ]]; then
  echo "Project directory not found" >&2
  exit 1
fi

ENV_FILE="${ENV_FILE:-$PROJECT_DIR/.env}"
EXPORT_ROOT="${EXPORT_ROOT:-/tmp/kafka-postgres-bi-exports}"
GCS_PREFIX="${GCS_PREFIX:-kafka-postgres-bi/exports}"
EXPORT_TIMEZONE="${EXPORT_TIMEZONE:-Asia/Bangkok}"

read_env_value() {
  local key="$1"
  local value
  value="$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true)"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s' "$value"
}

if [[ -f "$ENV_FILE" ]]; then
  POSTGRES_DB="${POSTGRES_DB:-$(read_env_value POSTGRES_DB)}"
  POSTGRES_USER="${POSTGRES_USER:-$(read_env_value POSTGRES_USER)}"
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(read_env_value POSTGRES_PASSWORD)}"
  GCS_EXPORT_BUCKET="${GCS_EXPORT_BUCKET:-$(read_env_value GCS_EXPORT_BUCKET)}"
fi

: "${POSTGRES_DB:=machine_monitoring}"
: "${POSTGRES_USER:=monitoring_user}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required in .env}"
: "${GCS_EXPORT_BUCKET:?GCS_EXPORT_BUCKET is required in .env}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required on the VM" >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required on the VM for GCS upload" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx 'kafka_vm_postgres'; then
  echo "kafka_vm_postgres is not running; cannot export PostgreSQL data" >&2
  exit 1
fi

RUN_DATE="$(TZ="$EXPORT_TIMEZONE" date +%F)"
RUN_TIME="$(TZ="$EXPORT_TIMEZONE" date +%H%M%S)"
GENERATED_AT="$(TZ="$EXPORT_TIMEZONE" date -Iseconds)"
EXPORT_DIR="$EXPORT_ROOT/$RUN_DATE/$RUN_TIME"
GCS_URI="gs://$GCS_EXPORT_BUCKET/$GCS_PREFIX/$RUN_DATE/$RUN_TIME"

mkdir -p "$EXPORT_DIR"

export_table() {
  local name="$1"
  local query="$2"
  local outfile="$EXPORT_DIR/$name.csv.gz"

  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" kafka_vm_postgres \
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -c "\\copy ($query) TO STDOUT WITH CSV HEADER" | gzip -c > "$outfile"
}

export_table "machine_events_raw" "select * from machine_events_raw order by event_time, event_id"
export_table "control_room_current_status" "select * from control_room_current_status"
export_table "control_room_machine_status" "select * from control_room_machine_status order by machine_id, line_id"
export_table "control_room_alert_feed" "select * from control_room_alert_feed order by event_time desc, machine_id"
export_table "dashboard_realtime_summary" "select * from dashboard_realtime_summary"

cat > "$EXPORT_DIR/manifest.json" <<EOF
{
  "project": "Kafka-VM-Postgres-BI",
  "generated_at": "$GENERATED_AT",
  "timezone": "$EXPORT_TIMEZONE",
  "postgres_db": "$POSTGRES_DB",
  "gcs_uri": "$GCS_URI",
  "tables": [
    "machine_events_raw",
    "control_room_current_status",
    "control_room_machine_status",
    "control_room_alert_feed",
    "dashboard_realtime_summary"
  ]
}
EOF

gcloud storage cp "$EXPORT_DIR"/* "$GCS_URI/"
echo "Export uploaded to $GCS_URI"
