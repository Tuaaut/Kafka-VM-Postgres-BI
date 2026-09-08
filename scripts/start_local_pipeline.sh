#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-.venv/bin/python}"
RUNTIME_DIR=".runtime"
LOG_DIR="logs"

mkdir -p "$RUNTIME_DIR" "$LOG_DIR"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Python runtime not found at $PYTHON_BIN"
  echo "Run: python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
  exit 1
fi

if [[ -f "$RUNTIME_DIR/consumer.pid" ]] && kill -0 "$(cat "$RUNTIME_DIR/consumer.pid")" >/dev/null 2>&1; then
  echo "Consumer already running with PID $(cat "$RUNTIME_DIR/consumer.pid")"
else
  nohup "$PYTHON_BIN" -u consumer/postgres_event_consumer.py > "$LOG_DIR/consumer.log" 2>&1 &
  echo $! > "$RUNTIME_DIR/consumer.pid"
  echo "Started consumer with PID $(cat "$RUNTIME_DIR/consumer.pid")"
fi

if [[ -f "$RUNTIME_DIR/producer.pid" ]] && kill -0 "$(cat "$RUNTIME_DIR/producer.pid")" >/dev/null 2>&1; then
  echo "Producer already running with PID $(cat "$RUNTIME_DIR/producer.pid")"
else
  PRODUCER_EVENT_INTERVAL_SECONDS="${PRODUCER_EVENT_INTERVAL_SECONDS:-60}" \
  PRODUCER_EVENTS_PER_BATCH="${PRODUCER_EVENTS_PER_BATCH:-10}" \
  nohup "$PYTHON_BIN" -u producer/machine_event_producer.py > "$LOG_DIR/producer.log" 2>&1 &
  echo $! > "$RUNTIME_DIR/producer.pid"
  echo "Started producer with PID $(cat "$RUNTIME_DIR/producer.pid")"
fi

echo "Pipeline logs:"
echo "  $LOG_DIR/consumer.log"
echo "  $LOG_DIR/producer.log"
