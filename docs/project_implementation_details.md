# Kafka Real-Time Monitoring Implementation Details

This project is a cost-conscious streaming showcase for machine-generated manufacturing data.

The business domain is intentionally similar to the earlier QR printing and IoT analytics work, but the engineering focus is different:

```text
Databricks project: historical analytics, lakehouse tables, KPI trend reporting
Kafka project: real-time event flow, operational monitoring, alerts, control-room dashboard
```

## Working Path

Current working pipeline:

```text
Python producer
→ Kafka topic machine_events
→ Python consumer
→ PostgreSQL machine_events_raw
→ PostgreSQL monitoring views
→ DBeaver / Grafana
```

Future historical path:

```text
Kafka
→ BigQuery / Fabric / Databricks
→ Historical analytics layer
```

The future path should not block the local demo. The first objective is to make Kafka, PostgreSQL, and Grafana work end to end.

## Why This Architecture

The project intentionally keeps PostgreSQL between Kafka and Grafana:

```text
Producer
→ Kafka
→ Consumer
→ PostgreSQL
→ Grafana
```

This was selected after discussing direct Kafka-to-Grafana and log-file-based alternatives.

Why not connect Grafana directly to Kafka:

- Kafka is a streaming backbone, not a dashboard-serving database.
- Grafana needs queryable state for counts, failure rate, latest lag, machine board, line KPIs, and alert feed.
- Alert rules are easier and more transparent when they use SQL against PostgreSQL.

Why not use JSON/log files directly:

- Files are useful as raw evidence, but awkward for live dashboard state.
- Cross-checking is harder without SQL.
- Alert rules and filtering become more fragile.

Why PostgreSQL is useful:

- It stores every valid consumed event.
- It exposes SQL views for Grafana.
- It supports DBeaver and terminal SQL checks.
- It gives us a clear way to compare dashboard numbers against source tables.
- It is cheap enough to run in the same Docker Compose stack on a small VM.

Why Grafana is useful:

- It fits control-room monitoring better than a traditional BI dashboard.
- It supports refresh, alerting, contact points, and provisioning-as-code.
- It is lightweight and shareable.
- It can show the same PostgreSQL views that we validate manually.

Design quality goals:

| Goal | Design choice |
| --- | --- |
| Resilience | Kafka buffers events and decouples producer and consumer. |
| Cost efficiency | One small VM can run the whole demo stack. |
| Flexibility | PostgreSQL views and Grafana panels can evolve without changing the event stream. |
| Cross-checking | DBeaver and terminal SQL can validate Grafana dashboard values. |
| Operational fit | Grafana is a natural fit for control-room monitoring and alerting. |
| Future expansion | More Kafka consumers can later feed BigQuery, Databricks, Fabric, or another warehouse. |

## Phase Status

### Phase 1: Local Streaming Pipeline

Status: working locally.

Done:

- Docker Compose starts Kafka, PostgreSQL, Grafana, producer, and consumer.
- Kafka runs as a single-node Apache Kafka KRaft broker.
- PostgreSQL initializes the schema and control-room views.
- Kafka topic `machine_events` can be created.
- Producer sends machine events to Kafka.
- Consumer reads Kafka events and writes valid events to PostgreSQL.
- Smoke-test messages that do not match the event contract are skipped by the consumer.
- Local fast test inserted 60 rows into PostgreSQL.

Important implementation choice:

```text
Kafka image: apache/kafka:3.7.0
Mode: single-node KRaft
Zookeeper: not used
```

Why:

```text
The earlier Confluent/Zookeeper direction was heavier for local testing.
The official Apache Kafka KRaft container is simpler and better for a small demo.
```

### Phase 2: Real-Time Monitoring Dashboard

Status: working in Grafana.

Prepared PostgreSQL views:

- `dashboard_realtime_summary`
- `control_room_current_status`
- `control_room_machine_status`
- `control_room_alert_feed`
- `machine_status_minute`
- `machine_alerts`

Done:

- Grafana connects to PostgreSQL using the provisioned PostgreSQL datasource.
- Dashboard shows current status, event freshness, event counts, failure rate, machine board, and alert feed.
- Refresh behavior is tested while the producer is running.

### Phase 3: GCP VM Deployment

Status: working on GCP Singapore.

Current VM:

```text
GCP project: YOUR_GCP_PROJECT_ID
Zone: asia-southeast1-a
VM name: kafka-postgres-bi-sg
Machine type: e2-small
Disk: 30 GB
OS: Ubuntu 24.04 LTS
```

Access:

```text
Grafana: http://localhost:3001 through SSH tunnel
PostgreSQL/DBeaver: localhost:5433 through SSH tunnel
```

Avoid for full stack:

```text
e2-micro
```

Reason:

```text
Kafka plus PostgreSQL plus Python producer and consumer can be tight on memory.
```

Upgrade path:

```text
Move to e2-medium only if resource monitoring shows pressure.
```

### Phase 4: Alerting Workflow

Status: design prepared, external notification not implemented yet.

First implementation can stay inside PostgreSQL and Grafana:

```text
Kafka events
→ PostgreSQL alert views
→ Grafana alert page / control-room page
```

Later extension:

```text
PostgreSQL query or service
→ email / Teams / Slack / ServiceNow / incident workflow
```

## Event Contract

Example event:

```json
{
  "event_id": "evt_001",
  "machine_id": "M001",
  "line_id": "L01",
  "event_type": "print_completed",
  "status": "success",
  "error_code": null,
  "temperature": 62.4,
  "speed": 98.1,
  "batch_id": "BATCH-001",
  "qr_code_id": "QR-001",
  "product_code": "SKU-001",
  "event_time": "2026-01-01T10:00:00Z"
}
```

Required fields for the consumer:

- `event_id`
- `machine_id`
- `event_type`
- `status`
- `event_time`

Optional but useful fields:

- `line_id`
- `error_code`
- `temperature`
- `speed`
- `batch_id`
- `qr_code_id`
- `product_code`

## Event Rate Decision

Default demo rate:

```text
10 events every 60 seconds
```

Expected rows:

```text
10 rows/minute
600 rows/hour
14,400 rows/day
100,800 rows/week
```

This is enough for live monitoring without generating unnecessary storage, CPU, or VM cost.

Alternative rates:

```text
5 events/minute  = 7,200 rows/day
20 events/minute = 28,800 rows/day
60 events/minute = 86,400 rows/day
```

For the local and GCP demo, stay at 10 events/minute unless load testing.

## Local Commands

Environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Start services:

```bash
scripts/start_services.sh
scripts/create_topics.sh
```

Manual consumer fallback:

```bash
source .venv/bin/activate
scripts/run_consumer.sh
```

Manual producer fallback:

```bash
source .venv/bin/activate
scripts/run_producer_60s.sh
```

Fast local test:

```bash
PRODUCER_EVENT_INTERVAL_SECONDS=1 PRODUCER_EVENTS_PER_BATCH=10 PRODUCER_MAX_BATCHES=3 .venv/bin/python producer/machine_event_producer.py
```

Query PostgreSQL:

```bash
scripts/query_postgres.sh "SELECT COUNT(*) AS rows_in_raw FROM machine_events_raw;"
scripts/query_postgres.sh "SELECT * FROM control_room_current_status;"
scripts/query_postgres.sh "SELECT * FROM control_room_machine_status;"
scripts/query_postgres.sh "SELECT * FROM control_room_alert_feed ORDER BY event_time DESC LIMIT 20;"
```

Reset event data:

```bash
scripts/reset_postgres_data.sh
```

Stop containers:

```bash
docker compose down
```

## Known Implementation Notes

- PostgreSQL is a Docker container. No native PostgreSQL installation is required on the Mac.
- DBeaver is useful for interactive SQL, but terminal SQL is faster for repeated Codex tasks.
- Grafana should query PostgreSQL directly through the provisioned datasource for this operational monitoring layer.
- Historical analytics should be kept separate from this local monitoring pipeline.
- `monitoring_rules` is currently a reference table. The status logic is encoded in SQL views and can later be made more dynamic.

## Remaining Work

1. Continue validating the Singapore e2-small VM during normal demo use.
2. Capture dashboard screenshots for the portfolio.
3. Configure Gmail SMTP alert delivery on the VM only when ready.
4. Keep PostgreSQL private and use DBeaver through the SSH tunnel.
5. Upgrade to e2-medium only if resource checks show pressure.
