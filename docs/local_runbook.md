# Local Runbook

Use this runbook when starting, testing, resetting, or troubleshooting the local Kafka/PostgreSQL demo.

For the GCP Singapore VM, use `docs/gcp_vm_operations.md`.

## What Runs Locally

```text
Docker Compose
├── Kafka: apache/kafka:3.7.0
├── PostgreSQL: postgres:16
├── Grafana: grafana/grafana-oss
├── Producer: local Python image
└── Consumer: local Python image
```

PostgreSQL runs in Docker. You do not need to install PostgreSQL directly on the Mac.

## One-Time Setup

From the project folder:

```bash
cd /Users/woraphu/Documents/Kafka-VM-Postgres-BI
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

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

```bash
scripts/run_consumer.sh
scripts/run_producer_60s.sh
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

## DBeaver

Use DBeaver when you want a GUI query interface.

Connection:

```text
Connection name: Kafka VM Postgres BI - Local
Host: localhost
Port: 5432
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

Useful starter queries:

```sql
SELECT * FROM dashboard_realtime_summary;
SELECT * FROM control_room_current_status;
SELECT * FROM control_room_machine_status;
SELECT * FROM control_room_alert_feed ORDER BY event_time DESC LIMIT 100;
```

GCP Singapore DBeaver connection:

```text
Connection name: Kafka VM Postgres BI - GCP Singapore Tunnel
Host: localhost
Port: 5433
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

This uses an SSH tunnel to the VM. `localhost:5433` on the Mac is forwarded to PostgreSQL on the VM.

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

That URL is also an SSH tunnel. `localhost:3001` on the Mac is forwarded to Grafana on the VM.

Alert email dashboard links use the configured Grafana root URL:

```text
GRAFANA_ROOT_URL=http://136.110.54.120:3000
```

This is intentional for operations-team emails. A technician cannot open a link to the owner's Mac localhost. If the VM public IP changes, update `GRAFANA_ROOT_URL` in `.env` and recreate Grafana.

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
docker compose --profile line-alerts up -d line-alert-bridge
```

Security rule:

```text
LINE_CHANNEL_ACCESS_TOKEN belongs only in local .env or a production secret store.
Do not write LINE tokens into docs or Git.
```

Current limitation:

```text
The Grafana LINE contact point is provisioned but not routed yet.
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
