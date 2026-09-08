#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/_venv.sh
source scripts/_venv.sh
PYTHON_BIN="$(resolve_python)"

"$PYTHON_BIN" -u consumer/postgres_event_consumer.py
