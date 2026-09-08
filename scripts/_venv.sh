# Resolve the virtualenv interpreter across layouts.
# Sourced by the run_*/start_* scripts. Linux/macOS venvs use bin/python;
# Windows venvs use Scripts/python.exe, which is why hardcoding
# .venv/bin/python fails under Git Bash on Windows.
resolve_python() {
  if [ -n "${PYTHON_BIN:-}" ]; then
    printf '%s' "$PYTHON_BIN"
    return 0
  fi
  for candidate in .venv/bin/python .venv/Scripts/python.exe; do
    if [ -x "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  echo "No virtualenv found at .venv. Create one first:" >&2
  echo "  python -m venv .venv && pip install -r requirements.txt" >&2
  echo "On Windows you can also use the PowerShell scripts in scripts/." >&2
  return 1
}
