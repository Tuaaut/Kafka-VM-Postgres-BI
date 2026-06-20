# Kafka Real-Time Monitoring & Analytics Project

This is the original project brief plus the current adaptation decisions.

The project demonstrates a streaming and analytics architecture using machine-generated data similar to QR code printing, beverage production, industrial equipment, or manufacturing systems.

The goal is to showcase:

1. Real-time operational monitoring.
2. Alert and suspicious-activity visibility.
3. Future historical analytics from the same event stream.

## Current Direction

Start locally first:

```text
Docker Kafka
→ Python producer
→ Python consumer
→ Docker PostgreSQL
→ DBeaver / Grafana
```

Then move to GCP:

```text
GCP Compute Engine VM
→ same Docker Compose stack
→ users access Grafana through SSH tunnel or restricted firewall
```

Current local pipeline status:

```text
Working
```

Current GCP status:

```text
Working on Singapore e2-small VM
VM: kafka-postgres-bi-sg
Zone: asia-southeast1-a
Grafana tunnel: http://localhost:3001
PostgreSQL/DBeaver tunnel: localhost:5433
Public Grafana dashboard: http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room
Alert email root URL: http://136.110.54.120:3000
```

Current alerting status:

```text
Gmail alerting: configured and verified for official searchable alert history
LINE alerting: LINE Official Account created and Messaging API broadcast test passed
LINE group push: not enabled yet; requires groupId capture and push-mode routing
```

Latest tested result:

```text
60 rows inserted into PostgreSQL
control_room_status = CRITICAL
failure_rate_pct = 10.00
```

The critical status is expected because the generated test data intentionally crossed the configured threshold.

## Business Context

Modern manufacturing and industrial systems continuously generate events:

- QR code printing events.
- Production events.
- Machine status updates.
- Error events.
- Sensor readings.
- Line performance metrics.
- Equipment health signals.

These events arrive continuously and must be processed quickly.

The architecture separates:

```text
Operational monitoring: what needs attention now?
Historical analytics: what happened over a longer period?
```

The same event stream can support both.

## Target Architecture

```text
Machine / Production Line Simulator
                |
                v
        Python Producer
                |
                v
       Kafka topic: machine_events
                |
                v
        Python Consumer
                |
                v
          PostgreSQL
        |
        v
   Grafana Dashboard
       Real-Time Monitoring
       Gmail Alert History
       LINE Fast Mobile Alerting


Future Historical Pipeline

Kafka
  |
  v
BigQuery / Fabric / Databricks
  |
  v
Historical Analytics
```

## Architecture Rationale

The selected architecture is:

```text
Producer
→ Kafka
→ Consumer
→ PostgreSQL
→ Grafana
```

This was chosen after comparing simpler and more direct alternatives.

Rejected direct path:

```text
Producer / Kafka
→ Grafana
```

Reason:

```text
Kafka is excellent for event streaming, buffering, and decoupling systems.
Kafka is not the best serving layer for dashboard queries, SQL checks, filters, alert feeds, or control-room status views.
```

Rejected log-file path:

```text
JSON / log files
→ Grafana
```

Reason:

```text
Log files are useful for raw evidence, but they are not ideal for reliable dashboard state, SQL validation, alert rule queries, or cross-checking operational metrics.
```

Why PostgreSQL stays in the architecture:

- It gives Grafana a stable query layer.
- It stores every valid Kafka event for replay, validation, and troubleshooting.
- It supports SQL views for machine status, line status, failure rate, ingest lag, and alert feed.
- It allows DBeaver or terminal SQL checks to cross-check what Grafana shows.
- It keeps the design low-cost because PostgreSQL runs in the same Docker Compose stack.
- It makes the demo more robust because Grafana does not depend on parsing raw files or reading directly from a stream.

Why Grafana is the dashboard layer:

- Grafana naturally fits control-room monitoring.
- It supports refresh intervals, alert rules, contact points, and dashboard-as-code.
- It is lightweight enough for a small VM demo.
- It is easier to share with viewers than direct database access.
- It keeps the operational dashboard separate from deeper historical analytics.

Why alerting uses two channels:

- Gmail keeps an official searchable record of alerts.
- LINE gives faster mobile attention for critical incidents.
- Critical alerts can reach technicians quickly while Gmail keeps the audit trail.

The final architecture is intentionally balanced:

| Goal | Architecture support |
| --- | --- |
| Resilience | Kafka buffers events and decouples producer from consumer. |
| Cost efficiency | All services run on one small VM for the demo. |
| Flexibility | PostgreSQL views can be changed without redesigning Kafka or Grafana. |
| Cross-checking | DBeaver and terminal SQL can validate the same data Grafana displays. |
| Dashboard reliability | Grafana queries PostgreSQL views instead of raw stream/log files. |
| Future growth | Extra consumers can later write to BigQuery, Databricks, Fabric, or another analytical store. |

## Infrastructure

### Local Development

Current local services:

```text
Kafka image: apache/kafka:3.7.0
Kafka mode: single-node KRaft, no Zookeeper
PostgreSQL image: postgres:16
Database: machine_monitoring
Kafka port: 9092
PostgreSQL port: 5432
```

No native PostgreSQL install is required because PostgreSQL runs as a Docker container.

### GCP VM Target

Current verified VM:

```text
GCP Compute Engine e2-small
2 shared vCPU
2 GB RAM
30 GB disk
Ubuntu 24.04 LTS
Region: asia-southeast1
Zone: asia-southeast1-a
```

Upgrade path if needed:

```text
e2-medium
```

Avoid for the full stack:

```text
e2-micro
```

## Core Components

### Kafka

Role:

- Event backbone.
- Event buffering.
- Producer and consumer decoupling.
- Future consumer expansion.

Current topic:

```text
machine_events
```

Future optional topics:

```text
production_events
machine_alerts
```

### Python Producer

Simulates machine-generated events.

Examples:

- Print completed.
- Print failed.
- Machine warning.
- Temperature reading.
- Production counter update.

Default rate:

```text
10 events every 60 seconds
```

Expected row volume:

```text
600 rows/hour
14,400 rows/day
```

### Python Consumer

Consumes Kafka events.

Responsibilities:

- Validate event shape.
- Skip invalid smoke-test messages.
- Transform event fields.
- Store valid events in PostgreSQL.

### PostgreSQL

Purpose:

- Operational data store.
- Fast querying.
- Live PostgreSQL query source for Grafana.
- Control-room semantic layer.

Main objects:

```text
machine_events_raw
production_events
machine_status_minute
machine_alerts
dashboard_realtime_summary
monitoring_rules
control_room_current_status
control_room_machine_status
control_room_alert_feed
```

### Grafana

Real-time monitoring mode:

```text
Connection mode: live PostgreSQL queries
Source: PostgreSQL
```

Purpose:

- Operational dashboard.
- Live monitoring.
- Incident visibility.
- Production tracking.
- Machine status board.
- Alert feed.

Historical analytics option:

```text
Source: BigQuery / Fabric / Databricks
```

Purpose:

- Trend analysis.
- Long-term reporting.
- Historical investigations.

## Data Model Direction

Example event structure:

```json
{
  "event_id": "evt_001",
  "machine_id": "QR_PRINTER_01",
  "line_id": "LINE_01",
  "event_type": "PRINT_EVENT",
  "status": "SUCCESS",
  "product_sku": "BEER_330_CAN",
  "print_result": "SUCCESS",
  "vision_result": "PASS",
  "reject_flag": false,
  "batch_id": "B202606201",
  "qr_code_id": "B202606201-LINE_01-123456",
  "event_time": "2026-01-01T10:00:00Z"
}
```

Required attributes:

- `event_id`
- `machine_id`
- `event_type`
- `status`
- `event_time`

Useful optional attributes:

- `line_id`
- `error_code`
- `temperature`
- `speed`
- `batch_id`
- `qr_code_id`
- `product_code`

## Control-Room Monitoring Model

This project does not copy the Databricks semantic model directly.

Databricks-style project:

```text
Historical facts
→ KPI / Gold semantic tables
→ trend dashboard
```

Kafka/PostgreSQL monitoring project:

```text
Latest event window
→ monitoring thresholds
→ current status
→ machine status board
→ live alert feed
```

Primary monitoring views:

```text
control_room_current_status
control_room_machine_status
control_room_alert_feed
```

## Project Phases

### Phase 1: Local Streaming Pipeline

Status:

```text
Working locally
```

Pipeline:

```text
Producer
→ Kafka
→ Consumer
→ PostgreSQL
```

Done:

- Kafka running.
- PostgreSQL running.
- Topic created.
- Events generated.
- Consumer writes events.
- PostgreSQL views return monitoring status.

### Phase 2: Real-Time Monitoring

Status:

```text
Working in Grafana
```

Pipeline:

```text
PostgreSQL
→ Grafana
```

Objectives:

- Operational dashboard.
- Live data visibility.
- Machine status board.
- Alert feed.

### Phase 3: GCP VM Deployment

Status:

```text
Working on GCP Singapore VM
```

Pipeline:

```text
GCP Compute Engine
→ Docker Compose
→ Kafka / PostgreSQL
→ Grafana connection
```

### Phase 4: Historical Analytics Layer

Status:

```text
Future phase
```

Pipeline:

```text
Kafka
→ BigQuery / Fabric / Databricks
```

Objectives:

- Historical storage.
- Trend reporting.
- Analytical dashboard.

### Phase 5: Alerting and Incident Workflow

Status:

```text
Gmail alerting working
```

Current integration:

```text
PostgreSQL alert views
→ Grafana alert rules
→ Gmail email contact point
→ operations-friendly alert email
```

Completed:

- Gmail SMTP configured with a Gmail App Password in local `.env`.
- Real SMTP test email received.
- Real Grafana `Plant State Critical` email received.
- Alert email message customized with impact, action plan, dashboard link, and resolution note.
- Alert email links use the VM public Grafana root URL.

Next optional channel:

```text
Grafana webhook
→ LINE Messaging API or Cloud Run bridge
→ LINE group chat
```

## Portfolio Value

This project demonstrates:

- Kafka.
- Event-driven architecture.
- Streaming data pipelines.
- Python data engineering.
- PostgreSQL operational serving.
- Real-time monitoring.
- Control-room dashboard design.
- Grafana.
- Future historical analytics architecture.
- Cost-conscious VM deployment.
- Multi-layer data platform design.

The project intentionally combines operational monitoring and analytical reporting using a shared event stream, while keeping the first demo focused on real-time Kafka monitoring.

## Detailed Documents

- `README.md`
- `docs/local_runbook.md`
- `docs/current_status.md`
- `docs/project_implementation_details.md`
- `docs/database_model.md`
- `docs/grafana_dashboard_plan.md`
- `docs/kpi_definitions.md`
- `docs/alerting_monitoring.md`
- `docs/infrastructure_resources.md`
- `docs/gcp_vm_setup.md`
