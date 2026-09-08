#!/usr/bin/env bash
set -euo pipefail

export PRODUCER_EVENT_INTERVAL_SECONDS="${PRODUCER_EVENT_INTERVAL_SECONDS:-60}"
export PRODUCER_EVENTS_PER_BATCH="${PRODUCER_EVENTS_PER_BATCH:-10}"

PYTHON_BIN="${PYTHON_BIN:-.venv/bin/python}"

"$PYTHON_BIN" producer/machine_event_producer.py
