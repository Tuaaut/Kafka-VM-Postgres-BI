# Infrastructure Resources

This file tracks local and cloud resources used by the Kafka real-time monitoring project.

## Local Development Environment

Current local architecture:

```text
Mac
→ Docker Compose
→ Kafka container
→ PostgreSQL container
→ Python producer and consumer containers
→ DBeaver / Grafana
→ optional LINE alert bridge
```

Local services:

| Service | Container | Image | Port | Purpose |
| --- | --- | --- | ---: | --- |
| Kafka | `kafka_vm_kafka` | `apache/kafka:3.7.0` | 9092 | Event streaming backbone. |
| PostgreSQL | `kafka_vm_postgres` | `postgres:16` | 5432 | Operational monitoring database. |
| Producer | `kafka_vm_producer` | local `Dockerfile` build | n/a | Emits machine events every 60 seconds. |
| Consumer | `kafka_vm_consumer` | local `Dockerfile` build | n/a | Writes Kafka events into PostgreSQL. |
| Grafana | `kafka_vm_grafana` | `grafana/grafana-oss:11.5.2` | 3000 | Monitoring dashboard and alerting UI. |
| LINE bridge | `line-alert-bridge` | local `Dockerfile` build | 8080 | Optional webhook bridge from Grafana to LINE Messaging API. |

Kafka mode:

```text
single-node KRaft
no Zookeeper
```

PostgreSQL mode:

```text
Docker container
local volume: postgres_data
database: machine_monitoring
user: monitoring_user
```

No native PostgreSQL install is required on the Mac.

## Local Connection Details

PostgreSQL:

```text
Host: localhost
Port: 5432
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

DBeaver:

```text
Connection name: Kafka VM Postgres BI - Local
Driver: PostgreSQL
Host: localhost
Port: 5432
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

Grafana:

```text
URL: http://localhost:3000
User: admin
Password: admin
Datasource host inside Docker: postgres:5432
Dashboard: Kafka Machine Monitoring Control Room
```

## Kafka

Purpose:

- Event backbone.
- Event buffering.
- Producer and consumer decoupling.
- Future consumer expansion.

Current topic:

```text
machine_events
```

Reserved future topics:

```text
production_events
machine_alerts
```

The project starts with one topic because it is easier to demo and debug. Split-by-domain topics can be added later if the demo needs more architecture depth.

## PostgreSQL

Purpose:

- Operational data store.
- Near real-time dashboard source.
- Grafana datasource backend.
- Lightweight semantic layer for control-room monitoring.

Current objects:

```text
machine_events_raw
production_events
machine_status_minute
machine_alerts
dashboard_realtime_summary
monitoring_rules
control_room_window_15m
control_room_current_status
control_room_machine_status
control_room_alert_feed
```

## Python Runtime

Local setup:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Main scripts:

```text
producer/machine_event_producer.py
consumer/postgres_event_consumer.py
```

Dockerized services:

```text
kafka_vm_producer
kafka_vm_consumer
```

Default producer settings:

```text
PRODUCER_EVENT_INTERVAL_SECONDS=60
PRODUCER_EVENTS_PER_BATCH=10
PRODUCER_MAX_BATCHES=
```

Expected default volume:

```text
14,400 events/day
```

## GCP VM Current Deployment

Current verified VM:

```text
Provider: Google Cloud Compute Engine
Project: YOUR_GCP_PROJECT_ID
Region: asia-southeast1
Zone: asia-southeast1-a
VM name: kafka-postgres-bi-sg
Machine type: e2-small
vCPU / RAM: 2 shared vCPU, 2 GB RAM
Disk: 30 GB standard persistent disk
OS: Ubuntu 24.04 LTS
Firewall: SSH only first
```

Upgrade path:

```text
e2-medium
2 shared vCPU, 4 GB RAM
Use only if e2-small becomes memory-constrained or slow.
```

Avoid for the full stack:

```text
e2-micro
```

Reason:

```text
Kafka, PostgreSQL, Python producer, and Python consumer together can be memory-sensitive.
```

## Resource Ledger

Current GCP setup:

```text
GCP project: YOUR_GCP_PROJECT_ID
GCP region: asia-southeast1
GCP zone: asia-southeast1-a
VM name: kafka-postgres-bi-sg
VM machine type: e2-small
VM OS: Ubuntu 24.04 LTS
Disk size: 30 GB standard persistent disk
External IP: EXTERNAL_IP_WHEN_RUNNING
Firewall rule: SSH only for testing; Grafana and PostgreSQL use SSH tunnels
Kafka image: apache/kafka:3.7.0
Kafka mode: single-node KRaft, no Zookeeper
PostgreSQL image: postgres:16
Python version: project Docker image runtime
DBeaver connection: Kafka VM Postgres BI - GCP Singapore Tunnel
Grafana URL: http://localhost:3001 through SSH tunnel
Public Grafana dashboard: http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room
Alert email root URL: http://136.110.54.120:3000
Grafana admin user: admin
Grafana read-only users: not created yet
Grafana dashboard: Kafka Monitoring / Kafka Machine Monitoring Control Room
Grafana dashboard file: grafana/dashboards/kafka_control_room.json
Grafana Gmail contact point: kafka-gmail-email
Grafana Gmail recipient: pattaratua@gmail.com
```

## External Alerting Resources

Gmail:

```text
Purpose: official searchable alert history
Sender: pattaratua@gmail.com
Recipient: pattaratua@gmail.com
Credential location: local .env only
Status: configured and verified
```

LINE:

```text
Purpose: fast mobile alert notification
Official Account: Kafka Alert Bot
Basic ID: @658ndqox
Provider: Kafka Monitoring Demo
Channel ID: 2010459362
Messaging API: enabled
Current send mode: broadcast
Status: direct LINE API test passed
```

Do not store Gmail App Passwords, LINE access tokens, or LINE channel secrets in Markdown or Git.

Dedicated LINE setup notes:

```text
docs/line_official_account_alerting.md
```

Operational runbook:

```text
docs/gcp_vm_operations.md
```

## Cost Controls

- Keep the VM stopped when not testing.
- Start on local Docker before paying for cloud runtime.
- Use `e2-small` while it remains stable.
- Upgrade to `e2-medium` only if resource checks show pressure.
- Keep producer volume at 10 events every 60 seconds.
- Keep PostgreSQL on the same VM during the demo phase.
- Keep PostgreSQL private whenever possible.
- For sharing, expose Grafana carefully instead of exposing PostgreSQL.
- If Grafana is exposed on a VM, restrict firewall source IPs and change the default admin password.
- Keep Gmail SMTP secrets only in local `.env` or a secure VM-only secret pattern.
- Keep LINE access tokens only in local `.env` or a secure VM-only secret pattern.
- Send only CRITICAL alerts to LINE at first.
- Keep `GRAFANA_ROOT_URL` aligned with the public/reachable URL that operations users should open from alert emails.
- Keep historical analytics as a later phase.
- Use the existing GCP budget alert as the first guardrail.

## Stop Commands

Stop containers but keep data:

```bash
docker compose stop
```

Stop and remove containers but keep named volume:

```bash
docker compose down
```

Delete PostgreSQL data volume:

```bash
docker compose down -v
```

Use `down -v` only when you intentionally want a clean database.
