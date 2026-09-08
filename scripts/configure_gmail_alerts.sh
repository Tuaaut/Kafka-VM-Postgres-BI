#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f .env ]; then
  cp .env.example .env
fi

printf "Gmail address used for SMTP: "
read -r smtp_user

printf "Alert recipient email [%s]: " "$smtp_user"
read -r alert_to
alert_to="${alert_to:-$smtp_user}"

printf "Gmail App Password for Grafana SMTP: "
read -rs smtp_password
printf "\n"

smtp_password="${smtp_password//[[:space:]]/}"

export smtp_user alert_to smtp_password

ruby <<'RUBY'
path = ".env"
values = {
  "GRAFANA_SMTP_ENABLED" => "true",
  "GRAFANA_SMTP_HOST" => "smtp.gmail.com:587",
  "GRAFANA_SMTP_USER" => ENV.fetch("smtp_user"),
  "GRAFANA_SMTP_PASSWORD" => ENV.fetch("smtp_password"),
  "GRAFANA_SMTP_FROM_ADDRESS" => ENV.fetch("smtp_user"),
  "GRAFANA_SMTP_FROM_NAME" => "Kafka Monitoring Grafana",
  "GRAFANA_SMTP_STARTTLS_POLICY" => "MandatoryStartTLS",
  "GRAFANA_ALERT_EMAIL_TO" => ENV.fetch("alert_to")
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

docker compose up -d --force-recreate grafana

echo "Gmail SMTP settings saved to local .env and Grafana was recreated."
echo "Check contact point:"
echo "  http://localhost:3000/alerting/notifications"
