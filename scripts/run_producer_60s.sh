#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/_venv.sh
source scripts/_venv.sh
PYTHON_BIN="$(resolve_python)"

export PRODUCER_EVENT_INTERVAL_SECONDS="${PRODUCER_EVENT_INTERVAL_SECONDS:-60}"
export PRODUCER_EVENTS_PER_BATCH="${PRODUCER_EVENTS_PER_BATCH:-10}"

"$PYTHON_BIN" producer/machine_event_producer.py
