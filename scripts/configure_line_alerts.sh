#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f .env ]; then
  cp .env.example .env
fi

printf "LINE Channel Access Token: "
read -rs line_token
printf "\n"

printf "LINE send mode [broadcast]: "
read -r line_send_mode
line_send_mode="${line_send_mode:-broadcast}"

printf "LINE target ID (required only for push mode; groupId preferred): "
read -r line_to_id

printf "Minimum severity for LINE alerts [critical]: "
read -r line_min_severity
line_min_severity="${line_min_severity:-critical}"

printf "Disable resolved messages for LINE? [true]: "
read -r line_disable_resolved
line_disable_resolved="${line_disable_resolved:-true}"

line_token="${line_token//[[:space:]]/}"
line_send_mode="${line_send_mode//[[:space:]]/}"

export line_token line_send_mode line_to_id line_min_severity line_disable_resolved

ruby <<'RUBY'
path = ".env"
values = {
  "LINE_CHANNEL_ACCESS_TOKEN" => ENV.fetch("line_token"),
  "LINE_SEND_MODE" => ENV.fetch("line_send_mode"),
  "LINE_TO_ID" => ENV.fetch("line_to_id"),
  "LINE_MIN_SEVERITY" => ENV.fetch("line_min_severity"),
  "LINE_DISABLE_RESOLVED" => ENV.fetch("line_disable_resolved")
}

lines = File.exist?(path) ? File.readlines(path, chomp: true) : []
seen = {}
lines = lines.map do |line|
  key = line.split("=", 2).first
  if values.key?(key)
    seen[key] = true
    "#{key}=#{values[key]}"
  else
    line
  end
end

values.each do |key, value|
  lines << "#{key}=#{value}" unless seen[key]
end

File.write(path, lines.join("\n") + "\n")
RUBY

echo "LINE alert settings saved to local .env."
echo "Secrets remain local because .env is ignored by Git."
