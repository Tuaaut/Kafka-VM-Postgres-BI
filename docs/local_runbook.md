# Local Runbook

Shell convention: `powershell` examples run on Windows. `bash` examples run on the Ubuntu VM or, for optional local development, inside WSL; they are not native PowerShell commands. WSL and a local pipeline are not required for the cloud-first workflow.

Optional development only: use this runbook when deliberately running the stack locally. The Windows workflow runs the pipeline on GCP; see [cloud operations](gcp_vm_operations.md). Bash examples require a compatible shell.

For the GCP Singapore VM, use `docs/gcp_vm_operations.md`.

## Purpose And Scope

The local Docker stack is a development and testing sandbox: iterate on SQL views, the Grafana dashboard, and alert-rule logic without waiting for the scheduled Saturday VM window.

Two intentional differences from the cloud VM:

- **Alerting is disabled locally.** Grafana SMTP is off (`GRAFANA_SMTP_ENABLED=false`) and `line-alert-bridge` is not started, so no email or LINE message is sent from local. Alert rules are still provisioned and evaluate, so `Firing`/`Normal` state is visible under Alerting in Grafana; only delivery is inert.
- **PostgreSQL is published on host port `5433`**, not `5432` (see the override file below).
- **No schedule locally.** Start and stop the stack on demand with `docker compose up -d` / `docker compose stop`. The Saturday 08:45-11:00 Asia/Bangkok window is a cloud cost-control measure (a GCP instance schedule); it does not apply to local Docker, which is free to run.

Once running, the producer emits 10 events every 60 seconds with no further action, so data flows into Grafana on its own. The cloud VM is the only environment that delivers alerts. Development flow: edit locally -> test in Docker -> commit -> copy changed files to the VM.

## Local Overrides: docker-compose.override.yml

`docker compose` merges `docker-compose.override.yml` automatically, so `docker-compose.yml` stays identical to the VM. The override applies local-only changes:

```yaml
services:
  postgres:
    ports: !override
      - "5433:5432"        # 5432 is used by another local project
  line-alert-bridge:
    profiles: ["alerting"] # excluded from the default `docker compose up`
```

To run the LINE bridge locally anyway (not normally needed):

```powershell
docker compose --profile alerting up -d
```

## Run From PowerShell (no WSL)

The `.sh` scripts in this runbook need WSL or Git Bash. The core loop also works from native PowerShell with plain Compose commands:

```powershell
docker compose up -d
docker compose ps
docker compose logs -f consumer
docker exec -it kafka_vm_postgres psql -U monitoring_user -d machine_monitoring
docker compose stop     # stop, keep data
docker compose down     # remove containers, keep the database volume
docker compose down -v  # remove containers and the database volume (reinitialize from sql/)
```

## What Runs Locally

```text
Docker Compose
├── Kafka: apache/kafka:3.7.0
├── PostgreSQL: postgres:16
├── Grafana: grafana/grafana-oss
├── Producer: local Python image
└── Consumer: local Python image
```

PostgreSQL runs in Docker. You do not need to install PostgreSQL directly on the Windows workstation.

## One-Time Setup

From the project folder:

```powershell
# Windows PowerShell
cd Kafka-VM-Postgres-BI
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
```

```bash
# macOS / Linux / WSL
cd Kafka-VM-Postgres-BI
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

`.env.example` sets `POSTGRES_PORT=5433` because `docker-compose.override.yml`
publishes Postgres on 5433 locally to avoid clashing with another project on
5432. Leaving it at 5432 makes the consumer hang on connect rather than fail
fast, so it looks alive while writing nothing.

## Start Services

```bash
scripts/start_services.sh
scripts/create_topics.sh
```

Expected services:

```text
kafka_vm_kafka
kafka_vm_postgres
kafka_vm_grafana
kafka_vm_producer
kafka_vm_consumer
```

Expected topic:

```text
machine_events
```

Check containers:

```bash
docker compose ps
```

## Live Producer And Consumer

The producer and consumer start automatically as Docker Compose services:

```text
kafka_vm_producer
kafka_vm_consumer
```

Producer behavior:

```text
10 events every 60 seconds
```

Check logs:

```bash
docker logs kafka_vm_producer --tail 50
docker logs kafka_vm_consumer --tail 50
```

If Grafana shows `NO DATA`, check these first:

```bash
docker compose ps
scripts/query_postgres.sh "SELECT COUNT(*) FILTER (WHERE event_time >= NOW() - INTERVAL '15 minutes') AS rows_15m, MAX(event_time) AS latest_event FROM machine_events_raw;"
```

Manual fallback scripts still exist for local debugging, but the normal project flow should use Docker Compose:

```powershell
# Windows PowerShell
.\scripts\Start-Consumer.ps1
.\scripts\Start-Producer.ps1
```

```bash
# macOS / Linux / WSL
scripts/run_consumer.sh
scripts/run_producer_60s.sh
```

### Running the pipeline in the background

The shell scripts track background processes with `nohup` and PID files, which
does not work from Windows: Git Bash hands out MSYS PIDs that Windows process
tools cannot see. Use the PowerShell equivalents on Windows.

| Task | Windows | macOS / Linux / WSL |
| --- | --- | --- |
| Start producer + consumer | `.\scripts\Start-LocalPipeline.ps1` | `scripts/start_local_pipeline.sh` |
| Check what is running | `.\scripts\Get-PipelineStatus.ps1` | `scripts/pipeline_status.sh` |
| Stop both | `.\scripts\Stop-LocalPipeline.ps1` | `scripts/stop_local_pipeline.sh` |
| Consumer in foreground | `.\scripts\Start-Consumer.ps1` | `scripts/run_consumer.sh` |
| Producer in foreground | `.\scripts\Start-Producer.ps1` | `scripts/run_producer_60s.sh` |
| LINE bridge locally | `.\scripts\Start-LineBridge.ps1` | `scripts/run_line_bridge_local.sh` |
| Send a test LINE alert | `.\scripts\Test-LineAlert.ps1` | `scripts/test_line_alert.sh` |

Both sides write logs to `logs/` and PID files to `.runtime/`, so status and
stop work regardless of which one started the processes on that platform. The
producer rate can be overridden either way:

```powershell
.\scripts\Start-LocalPipeline.ps1 -EventIntervalSeconds 5 -EventsPerBatch 5
```

## Fast Local Test

Use this when you want quick evidence that the pipeline works:

```bash
PRODUCER_EVENT_INTERVAL_SECONDS=1 PRODUCER_EVENTS_PER_BATCH=10 PRODUCER_MAX_BATCHES=3 .venv/bin/python producer/machine_event_producer.py
```

Expected output:

```text
30 events are sent over about 3 seconds
```

If you run this twice, expect about 60 rows if the consumer is running.

## Verify PostgreSQL

Summary:

```bash
scripts/verify_postgres_counts.sh
```

Raw row count:

```bash
scripts/query_postgres.sh "SELECT COUNT(*) AS rows_in_raw FROM machine_events_raw;"
```

Control-room status:

```bash
scripts/query_postgres.sh "SELECT * FROM control_room_current_status;"
```

Machine status:

```bash
scripts/query_postgres.sh "SELECT * FROM control_room_machine_status;"
```

Alert feed:

```bash
scripts/query_postgres.sh "SELECT * FROM control_room_alert_feed ORDER BY event_time DESC LIMIT 20;"
```

Interactive SQL:

```bash
scripts/query_postgres.sh
```

## Offline Review From GCS Export

The VM PostgreSQL database is unavailable when the VM is stopped. For offline review, the VM exports PostgreSQL snapshots to Cloud Storage before shutdown. The Windows workstation does not need to be online during the VM export.

GCS export bucket:

```text
gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp
```

Export path pattern:

```text
gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp/kafka-postgres-bi/exports/YYYY-MM-DD/HHMMSS/
```

Exported files:

```text
machine_events_raw.csv.gz
control_room_current_status.csv.gz
control_room_machine_status.csv.gz
control_room_alert_feed.csv.gz
dashboard_realtime_summary.csv.gz
manifest.json
```

The export is produced by:

```text
scripts/export_vm_postgres_to_gcs.sh
scripts/install_vm_shutdown_export_service.sh
```

For the current cloud-first workflow, download and decompress CSV files for offline inspection; no local database is required. Import into a local database is optional development work only.

Optional queries after a manual local database import:

```sql
SELECT COUNT(*) AS local_rows_total, MAX(event_time) AS latest_event_time
FROM machine_events_raw;

SELECT *
FROM control_room_current_status;

SELECT *
FROM control_room_alert_feed
ORDER BY event_time DESC
LIMIT 100;
```

Online/offline rule:

```text
The VM can start, produce data, and stop without the Windows workstation being online.
The VM export to GCS does not depend on the Windows workstation.
Download and inspect CSV snapshots later on Windows; no automatic synchronization is configured.
Cloud Storage lifecycle deletes old export objects after 5 days.
```

## Grafana

Open Grafana:

```text
http://localhost:3000
```

Login:

```text
User: admin
Password: admin
```

Provisioned dashboard:

```text
Kafka Monitoring / Kafka Machine Monitoring Control Room
```

Grafana uses the provisioned PostgreSQL datasource:

```text
Host inside Docker: postgres:5432
Database: machine_monitoring
User: monitoring_user
```

Do not change Grafana's datasource host to `localhost` while Grafana is running in Docker.

GCP Singapore Grafana uses:

```text
http://localhost:3001
```

That URL is also an SSH tunnel. `localhost:3001` on the Windows workstation is forwarded to Grafana on the VM.

Alert email dashboard links use the configured Grafana root URL:

```text
GRAFANA_ROOT_URL=http://136.110.54.120:3000
```

This is intentional for operations-team emails. A technician cannot open a link to the owner's Windows workstation localhost. If the VM public IP changes, update `GRAFANA_ROOT_URL` in `.env` and recreate Grafana.

## Grafana Alert Rules

Local alert rules are provisioned from:

```text
grafana/provisioning/alerting/kafka_alert_rules.yml
```

Current rules:

```text
Plant State Critical
Ingest Lag Above 300s
```

Gmail contact point file:

```text
grafana/provisioning/alerting/gmail_contact_point.yml
```

Configure Gmail SMTP locally:

```bash
scripts/configure_gmail_alerts.sh
```

Use a Gmail App Password, not the normal Gmail password.

Current verified Gmail alerting status:

```text
Sender: pattaratua@gmail.com
Recipient: pattaratua@gmail.com
Real SMTP test email: received
Real Grafana Plant State Critical email: received
Alert email message: customized with summary, impact, action plan, dashboard link, and resolution note
```

Do not write the Gmail App Password into docs or Git. It belongs only in local `.env` or a secure VM-only secret pattern.

Recreate Grafana after changing SMTP environment variables:

```bash
docker compose up -d --force-recreate grafana
```

Check provisioning logs:

```bash
docker logs kafka_vm_grafana --since 2m | grep -i provisioning
```

List provisioned alert rules:

```bash
curl -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules
```

Open in Grafana:

```text
Alerting → Alert rules
Alerting → Contact points
Alerting → Notification policies
```

If `.env` is missing or SMTP is disabled, the contact point falls back to placeholder values and delivery can fail. In the current local setup, Gmail SMTP has been configured and verified.

## LINE Alerting

LINE is prepared as the fast mobile response channel.

Dedicated setup document:

```text
docs/line_official_account_alerting.md
```

Current local mode:

```text
LINE_SEND_MODE=broadcast
LINE_MIN_SEVERITY=critical
LINE_DISABLE_RESOLVED=true
Grafana critical route: enabled
```

Run a direct LINE alert test:

```bash
scripts/test_line_alert.sh
```

Expected success:

```json
{
  "sent": true,
  "status": 200,
  "response": "{}"
}
```

Known verified route:

```text
Grafana Plant State Critical -> kafka-line-webhook -> LINE bridge /grafana -> HTTP 200
```

Run the bridge locally:

```bash
scripts/run_line_bridge_local.sh
```

Health check:

```bash
curl http://localhost:8080/health
```

Docker Compose bridge option:

```bash
docker compose up -d line-alert-bridge
```

Security rule:

```text
LINE_CHANNEL_ACCESS_TOKEN belongs only in local .env or a production secret store.
Do not write LINE tokens into docs or Git.
```

Current limitation:

```text
True group-chat push needs a captured groupId and LINE_SEND_MODE=push.
```

## Reset Data

Clear event rows but keep the schema:

```bash
scripts/reset_postgres_data.sh
```

Use this before a clean demo run.

## Stop Services

Stop containers but keep data:

```bash
docker compose stop
```

Stop and remove containers but keep database volume:

```bash
docker compose down
```

Delete database volume:

```bash
docker compose down -v
```

Use `down -v` only if you want PostgreSQL to reinitialize from the SQL files.

## Troubleshooting

### PostgreSQL is not ready

Check:

```bash
docker logs kafka_vm_postgres --tail 100
docker exec kafka_vm_postgres pg_isready -U monitoring_user -d machine_monitoring
```

### Kafka topic missing

Run:

```bash
scripts/create_topics.sh
```

List topics:

```bash
docker exec kafka_vm_kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

### Consumer runs but no rows appear

Check:

```bash
docker compose ps
scripts/query_postgres.sh "SELECT COUNT(*) FROM machine_events_raw;"
```

Then confirm producer is running and sending valid events.

### Smoke-test message appears in Kafka but not PostgreSQL

This can be correct. The consumer skips messages that do not contain required machine event fields.

### Port conflict

Kafka uses:

```text
9092
```

PostgreSQL uses:

```text
5432
```

If either port is already used, stop the conflicting service or change the Docker Compose port mapping.

### Clean rebuild

Use only when you want a fresh PostgreSQL database:

```bash
docker compose down -v
scripts/start_services.sh
scripts/create_topics.sh
```

## Demo Flow

1. Reset data with `scripts/reset_postgres_data.sh`.
2. Start Kafka and PostgreSQL.
3. Create Kafka topic.
4. Start consumer.
5. Start producer.
6. Open Grafana at `http://localhost:3000`.
7. Watch `control_room_current_status`.
8. Open `control_room_alert_feed` when status becomes `WARNING` or `CRITICAL`.
