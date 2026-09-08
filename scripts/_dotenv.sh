# Load .env into the environment. Sourced by scripts that need credentials.
load_dotenv() {
  [ -f .env ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    [ "$key" = "$line" ] && continue
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    export "$key=$value"
  done < .env
}
