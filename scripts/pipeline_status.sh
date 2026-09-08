#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR=".runtime"

check_pid() {
  local name="$1"
  local pid_file="$RUNTIME_DIR/$name.pid"

  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" >/dev/null 2>&1; then
    echo "$name: running (PID $(cat "$pid_file"))"
  else
    echo "$name: stopped"
  fi
}

check_pid "producer"
check_pid "consumer"
