#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR=".runtime"

stop_pid() {
  local name="$1"
  local pid_file="$RUNTIME_DIR/$name.pid"

  if [[ ! -f "$pid_file" ]]; then
    echo "$name is not running; no PID file."
    return
  fi

  local pid
  pid="$(cat "$pid_file")"
  if kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid"
    echo "Stopped $name with PID $pid"
  else
    echo "$name PID $pid is not active."
  fi
  rm -f "$pid_file"
}

stop_pid "producer"
stop_pid "consumer"
