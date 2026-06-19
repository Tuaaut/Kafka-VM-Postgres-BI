#!/usr/bin/env bash
set -euo pipefail

docker compose up -d

echo "Waiting for PostgreSQL..."
until docker exec kafka_vm_postgres pg_isready -U monitoring_user -d machine_monitoring >/dev/null 2>&1; do
  sleep 2
done

echo "Waiting for Grafana..."
until curl -fsS http://localhost:3000/api/health >/dev/null 2>&1; do
  sleep 2
done

echo "Services are ready."
docker compose ps
