#!/usr/bin/env bash
# Start the producer and consumer in the background (Linux/macOS/WSL).
#
# On Windows use scripts/Start-LocalPipeline.ps1 instead: the PID tracking
# below relies on POSIX process semantics, and PIDs from Git Bash are MSYS
# PIDs that Windows tools cannot see.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/_venv.sh
source scripts/_venv.sh
PYTHON_BIN="$(resolve_python)"

RUNTIME_DIR=".runtime"
LOG_DIR="logs"
mkdir -p "$RUNTIME_DIR" "$LOG_DIR"

start_bg() {
  local name="$1"
  shift
  local pid_file="$RUNTIME_DIR/$name.pid"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" >/dev/null 2>&1; then
    echo "$name already running with PID $(cat "$pid_file")"
    return 0
  fi

  nohup "$@" > "$LOG_DIR/$name.log" 2>&1 &
  echo $! > "$pid_file"
  echo "Started $name with PID $(cat "$pid_file")"
}

start_bg consumer "$PYTHON_BIN" -u consumer/postgres_event_consumer.py

PRODUCER_EVENT_INTERVAL_SECONDS="${PRODUCER_EVENT_INTERVAL_SECONDS:-60}" \
PRODUCER_EVENTS_PER_BATCH="${PRODUCER_EVENTS_PER_BATCH:-10}" \
  start_bg producer "$PYTHON_BIN" -u producer/machine_event_producer.py

echo
bash scripts/pipeline_status.sh
