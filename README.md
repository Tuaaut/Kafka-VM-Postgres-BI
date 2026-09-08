# Kafka Real-Time Manufacturing Monitoring

Shell convention: `powershell` examples run on Windows. `bash` examples run on the Ubuntu VM or, for optional local development, inside WSL; they are not native PowerShell commands. WSL and a local pipeline are not required for the cloud-first workflow.

This project shows how a manufacturing team can monitor machine events in near real time using Kafka, PostgreSQL, and Grafana.

## Current Operating Model — Cloud First

The pipeline runs on the GCP VM during the scheduled Saturday demo window, 08:45–11:00 Asia/Bangkok. Windows is used for project files, browser access, and occasional cloud administration. A desktop database client, local database, and persistent PostgreSQL tunnel are not required.

| # | When | How to review the project |
| --- | --- | --- |
| 1 | VM running during the demo | Open the [Grafana dashboard](http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room). |
| 2 | VM stopped | Download/decompress available CSV snapshots from [Cloud Storage exports](https://console.cloud.google.com/storage/browser/kafka-postgres-bi-exports-retail-bigquery-project-webapp/kafka-postgres-bi/exports?project=retail-bigquery-project-webapp). The configured retention is five days. |
| 3 | Occasional troubleshooting | Use browser SSH in GCP Console and run psql inside the existing VM PostgreSQL container while the VM is already on. |

PostgreSQL remains the operational data store used by Grafana. Stopping the VM makes both live SQL and Grafana unavailable; GCS exports remain separate snapshots. Removing a desktop client simplifies Windows setup but does not itself change cloud uptime or cost.

See [Windows/cloud operations](docs/gcp_vm_operations.md#windows-cloud-access-verified-2026-09-05) and [progress and decisions](docs/current_status.md#cloud-first-windows-workflow--2026-09-05). The local Compose instructions below are optional development, not normal Windows setup.

The business story is a QR-printing production line that continuously emits Fabric-aligned events: print quality checks, telemetry, and machine fault logs. The goal is to help an operations team quickly answer:

- Are production events still flowing?
- Which machines or lines need attention?
- Are failures, warnings, or high temperatures increasing?
- Is the dashboard showing fresh data?
- Can the same event stream support future analytics?

![Grafana control-room dashboard](docs/screenshots/grafana-control-room-dashboard-viewport.png)

## Business Logic

The project treats each machine event as an operational signal. Events are streamed, stored, checked against monitoring rules, and shown in a control-room dashboard.

The dashboard highlights:

- Plant status: `NORMAL`, `WARNING`, `CRITICAL`, or `NO_DATA`
- Recent event volume
- Failure rate
- Critical alert count
- Ingest lag
- Machine-level status
- Recent alert feed

This makes the demo useful for monitoring current production health, not just reporting historical results.

## Business Layer

The business layer is organized around production operations:

| Layer | Purpose |
| --- | --- |
| Machine events | Simulated `LINE_01` / `QR_PRINTER_01` signals such as `PRINT_EVENT`, `MACHINE_TELEMETRY`, `MACHINE_LOG`, `SUCCESS`, `FAILED`, and `FAULTED`. |
| Monitoring rules | Thresholds for failure rate, warning volume, temperature, and ingest lag. |
| Control-room views | PostgreSQL views that convert raw events into current plant status, machine status, and alert feed. |
| Grafana dashboard | A live operations dashboard for supervisors or support teams. |

## Solution Architecture

```text
Machine event simulator
        |
        v
Python producer
        |
        v
Kafka topic: machine_events
        |
        v
Python consumer
        |
        v
PostgreSQL operational store
        |
        v
PostgreSQL monitoring views
        |
        v
Grafana control-room dashboard
```

Kafka is used as the event backbone. PostgreSQL is used as the operational serving layer so Grafana can query clean, trusted views. Grafana is used for monitoring, visual status, and alert visibility.

The same architecture can later be extended to send Kafka events into BigQuery, Databricks, Fabric, or another historical analytics platform.

## Tech Stack

- Apache Kafka for event streaming
- Python producer and consumer services
- PostgreSQL for operational storage and SQL monitoring views
- Grafana for the real-time dashboard and alert rules
- Gmail SMTP for searchable operational alert history
- LINE Messaging API for fast mobile alert notification
- Docker Compose for local orchestration
- GCP Compute Engine for optional cloud demo deployment

## Current Status

The pipeline has been verified end to end and is deployed on the scheduled GCP VM:

```text
Producer -> Kafka -> Consumer -> PostgreSQL -> Grafana
```

The project also has a tested GCP VM deployment path. The VM uses a scheduled UAT/demo window instead of running 24/7.

Before scheduled shutdown, the VM is configured to export PostgreSQL snapshots to Cloud Storage so the data can be reviewed later even if the Windows workstation was offline during the demo window. Verify export completion when reviewing a demo run.

Gmail alerting is also configured and verified:

```text
Grafana alert rule -> Gmail email contact point -> pattaratua@gmail.com
```

The current email alert format includes status, severity, impact, action plan, dashboard link, and resolution note. Gmail is used as the official searchable alert record.

LINE alerting is prepared and the first real LINE Messaging API test passed:

```text
Kafka Alert Bot -> LINE Messaging API broadcast -> LINE Official Account friends
```

LINE is the fast mobile response channel. Gmail remains the official alert-history channel.

## Grafana Access

Public dashboard:

```text
http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room
```

The public dashboard opens in anonymous viewer mode, so visitors do not need to register or log in.

Grafana alert emails use this VM public base URL for dashboard links:

```text
http://136.110.54.120:3000
```

Local dashboard:

```text
http://localhost:3000
```

The public URL is available while the GCP VM is running. The VM is scheduled to start before the UAT/demo window and stop afterward to control cost.

Current scheduled demo window:

```text
Frequency: Every Saturday
Start: Saturday 08:45 Asia/Bangkok
Stop: Saturday 11:00 Asia/Bangkok
Resource policy: kafka-demo-uat-hours
Startup script: scripts/gcp_vm_startup.sh
Pre-shutdown export: scripts/export_vm_postgres_to_gcs.sh
GCS bucket: gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp
```

When the VM starts, the startup script runs Docker Compose so Kafka, PostgreSQL, Grafana, producer, consumer, and the LINE alert bridge come online automatically.

Default local admin login:

```text
admin / admin
```

## Explore More

For deeper technical details, use these documents:

- [Technical README](docs/technical_readme.md)
- [Implementation details](docs/project_implementation_details.md)
- [Database model](docs/database_model.md)
- [KPI definitions](docs/kpi_definitions.md)
- [Grafana dashboard plan](docs/grafana_dashboard_plan.md)
- [Alerting and monitoring](docs/alerting_monitoring.md)
- [LINE Official Account alerting](docs/line_official_account_alerting.md)
- [Local runbook](docs/local_runbook.md)
- [GCP VM operations](docs/gcp_vm_operations.md)

## Local Development (Docker)

The local Docker stack is the sandbox for iterating on SQL views, the Grafana dashboard, and alert-rule logic without waiting for the scheduled Saturday VM window. It runs the same `docker-compose.yml` as the VM; only `.env` and `docker-compose.override.yml` differ.

Two intentional differences from the cloud VM:

- **No alerting.** Grafana SMTP is disabled and the LINE bridge is not started, so no email or LINE message is ever sent from local. Alert rules still evaluate, so `Firing`/`Normal` state is visible in the Grafana UI; only delivery is inert.
- **PostgreSQL host port is `5433`** (not `5432`), set in `docker-compose.override.yml` to avoid clashing with other local projects. Grafana reaches PostgreSQL in-network on `postgres:5432`.

Start the stack (PowerShell, from the project folder):

```powershell
docker compose up -d
docker compose ps
```

Open local Grafana at `http://localhost:3000` (`admin` / `admin`).

Stop when done (keeps data):

```powershell
docker compose stop
```

`docker compose down -v` removes the containers and the database volume so PostgreSQL reinitializes from `sql/`.

The `scripts/*.sh` helpers, the Python `.venv`, and `cp .env.example .env` are conveniences for a WSL or Git Bash shell; they are not required for the Docker flow above. See [docs/local_runbook.md](docs/local_runbook.md).

Development flow: edit locally -> test in Docker -> commit -> copy changed files to the VM (the VM has no Git checkout).
