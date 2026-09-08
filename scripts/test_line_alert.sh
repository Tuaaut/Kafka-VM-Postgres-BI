#!/usr/bin/env bash
# Send one sample critical alert through the LINE bridge.
# The payload lives in scripts/send_test_line_alert.py so this and
# Test-LineAlert.ps1 run the same code.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck source=scripts/_venv.sh
source scripts/_venv.sh
# shellcheck source=scripts/_dotenv.sh
source scripts/_dotenv.sh

load_dotenv
PYTHON_BIN="$(resolve_python)"

"$PYTHON_BIN" scripts/send_test_line_alert.py
