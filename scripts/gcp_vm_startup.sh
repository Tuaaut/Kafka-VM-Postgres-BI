#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/kafka-monitoring-startup.log"
PROJECT_DIR=""

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date -Is)] Kafka monitoring startup begin"

for candidate in \
  /home/*/Kafka-VM-Postgres-BI \
  /root/Kafka-VM-Postgres-BI \
  /opt/Kafka-VM-Postgres-BI
do
  if [ -d "$candidate" ]; then
    PROJECT_DIR="$candidate"
    break
  fi
done

if [ -z "$PROJECT_DIR" ]; then
  echo "[$(date -Is)] Project directory not found"
  exit 1
fi

echo "[$(date -Is)] Project directory: $PROJECT_DIR"
cd "$PROJECT_DIR"

echo "[$(date -Is)] Removing macOS archive metadata files if present"
find . -name '._*' -type f -delete

if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  echo "[$(date -Is)] Pulling latest GitHub changes"
  git pull --ff-only || echo "[$(date -Is)] git pull failed; continuing with existing checkout"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[$(date -Is)] Docker is not installed or not on PATH"
  exit 1
fi

echo "[$(date -Is)] Starting Docker Compose stack"
docker compose up -d --build

echo "[$(date -Is)] Current container status"
docker compose ps

echo "[$(date -Is)] Kafka monitoring startup complete"
