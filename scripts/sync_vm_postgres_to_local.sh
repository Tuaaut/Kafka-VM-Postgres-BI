#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-retail-bigquery-project-webapp}"
ZONE="${ZONE:-asia-southeast1-a}"
VM_NAME="${VM_NAME:-kafka-postgres-bi-sg}"
REMOTE_TUNNEL_PORT="${REMOTE_TUNNEL_PORT:-55433}"

POSTGRES_DB="${POSTGRES_DB:-machine_monitoring}"
POSTGRES_USER="${POSTGRES_USER:-monitoring_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-monitoring_password}"

LOCAL_HOST="${LOCAL_HOST:-localhost}"
LOCAL_PORT="${LOCAL_PORT:-5432}"
REMOTE_HOST="${REMOTE_HOST:-localhost}"
REMOTE_PORT="${REMOTE_PORT:-5432}"

EXPORT_DIR="${EXPORT_DIR:-data_exports/vm_postgres}"
mkdir -p "$EXPORT_DIR"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd gcloud
require_cmd docker
require_cmd psql

vm_status="$(gcloud compute instances describe "$VM_NAME" \
  --project "$PROJECT_ID" \
  --zone "$ZONE" \
  --format='value(status)')"

if [ "$vm_status" != "RUNNING" ]; then
  echo "VM is $vm_status. Start it before syncing, or wait for the scheduled UAT window." >&2
  exit 1
fi

docker compose up -d postgres >/dev/null

export PGPASSWORD="$POSTGRES_PASSWORD"

echo "Checking local PostgreSQL..."
until psql -h "$LOCAL_HOST" -p "$LOCAL_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; do
  sleep 2
done

local_max_ingest="$(psql -h "$LOCAL_HOST" -p "$LOCAL_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
  "SELECT COALESCE(MAX(ingest_time), TIMESTAMPTZ '1970-01-01 00:00:00+00') FROM machine_events_raw;")"

echo "Local max ingest_time: $local_max_ingest"

tunnel_pid=""
cleanup() {
  if [ -n "$tunnel_pid" ] && kill -0 "$tunnel_pid" >/dev/null 2>&1; then
    kill "$tunnel_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if ! nc -z "$REMOTE_HOST" "$REMOTE_TUNNEL_PORT" >/dev/null 2>&1; then
  echo "Opening SSH tunnel localhost:${REMOTE_TUNNEL_PORT} -> VM localhost:${REMOTE_PORT}"
  gcloud compute ssh "$VM_NAME" \
    --project "$PROJECT_ID" \
    --zone "$ZONE" \
    -- -N -L "${REMOTE_TUNNEL_PORT}:${REMOTE_HOST}:${REMOTE_PORT}" &
  tunnel_pid="$!"
  sleep 5
fi

echo "Checking remote PostgreSQL through tunnel..."
until psql -h "$REMOTE_HOST" -p "$REMOTE_TUNNEL_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" >/dev/null 2>&1; do
  sleep 2
done

timestamp="$(date +%Y%m%d_%H%M%S)"
csv_path="${EXPORT_DIR}/machine_events_raw_incremental_${timestamp}.csv"
sql_path="${EXPORT_DIR}/import_machine_events_raw_${timestamp}.sql"

echo "Exporting VM rows newer than local max ingest_time..."
psql -h "$REMOTE_HOST" -p "$REMOTE_TUNNEL_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -c \
  "\\copy (SELECT * FROM machine_events_raw WHERE ingest_time > TIMESTAMPTZ '${local_max_ingest}' ORDER BY ingest_time, event_id) TO '${csv_path}' WITH CSV HEADER"

rows_exported="$(( $(wc -l < "$csv_path") - 1 ))"
if [ "$rows_exported" -le 0 ]; then
  echo "No new rows to import."
  exit 0
fi

cat > "$sql_path" <<SQL
\\set ON_ERROR_STOP on
BEGIN;
CREATE TEMP TABLE machine_events_raw_import (LIKE machine_events_raw INCLUDING DEFAULTS);
\\copy machine_events_raw_import FROM '${csv_path}' WITH CSV HEADER
INSERT INTO machine_events_raw
SELECT *
FROM machine_events_raw_import
ON CONFLICT (event_id) DO NOTHING;
COMMIT;
SQL

echo "Importing ${rows_exported} exported rows into local PostgreSQL..."
psql -h "$LOCAL_HOST" -p "$LOCAL_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$sql_path"

echo "Local mirror status:"
psql -h "$LOCAL_HOST" -p "$LOCAL_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT COUNT(*) AS local_rows_total, MAX(event_time) AS latest_event_time, MAX(ingest_time) AS latest_ingest_time FROM machine_events_raw;"

echo "Saved export: $csv_path"
