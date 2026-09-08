#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/_venv.sh
source scripts/_venv.sh
# shellcheck source=scripts/_dotenv.sh
source scripts/_dotenv.sh

load_dotenv
PYTHON_BIN="$(resolve_python)"
export PORT="${PORT:-8080}"

"$PYTHON_BIN" alerting/line_alert_bridge.py
