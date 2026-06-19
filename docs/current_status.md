# Current Project Status

This file records the current known state of the project so we can return later without guessing.

## Summary

The local Kafka to PostgreSQL pipeline works, and the same stack is now running on a Singapore GCP VM.

Working path:

```text
Python producer
→ Kafka topic machine_events
→ Python consumer
→ PostgreSQL machine_events_raw
→ PostgreSQL monitoring views
```

## Local Services

Kafka:

```text
Container: kafka_vm_kafka
Image: apache/kafka:3.7.0
Port: 9092
Mode: single-node KRaft
Zookeeper: not used
```

PostgreSQL:

```text
Container: kafka_vm_postgres
Image: postgres:16
Port: 5432
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

Grafana:

```text
Container: kafka_vm_grafana
Image: grafana/grafana-oss:11.5.2
Port: 3000
URL: http://localhost:3000
User: admin
Password: admin
Dashboard: Kafka Monitoring / Kafka Machine Monitoring Control Room
```

Kafka topic:

```text
machine_events
```

## Confirmed Local Test Result

The full local flow was tested with producer and consumer running.

Observed PostgreSQL result:

```text
rows_in_raw = 60
control_room_status = CRITICAL
total_events = 60
successful_events = 49
failed_events = 6
warning_events = 5
failure_rate_pct = 10.00
latest_lag_seconds = about 0.02
```

Alert feed counts:

```text
CRITICAL = 7
WARNING = 6
```

Interpretation:

```text
The pipeline is healthy, and the control-room logic correctly flagged a critical condition because the generated test data reached the configured 10% failure-rate threshold.
```

## Confirmed Grafana Result

Grafana has been added to Docker Compose and verified locally.

Confirmed:

```text
Grafana health API: ok
Datasource: Machine Monitoring Postgres
Dashboard: Kafka Machine Monitoring Control Room
Dashboard includes top KPIs, event flow, machine board, production line KPIs, production line event flow, and alert feed
Local alert rules: Plant State Critical, Ingest Lag Above 300s
```

## Confirmed GCP Singapore Result

The cloud demo is running on GCP:

```text
Project: YOUR_GCP_PROJECT_ID
Region: asia-southeast1
Zone: asia-southeast1-a
VM name: kafka-postgres-bi-sg
Machine type: e2-small
Disk: 30 GB standard persistent disk
External IP: EXTERNAL_IP_WHEN_RUNNING
Access model: SSH tunnel first
```

Confirmed:

```text
Docker Compose stack is running on the VM.
Grafana dashboard opens from the Mac through http://localhost:3001.
PostgreSQL opens from DBeaver through localhost:5433.
Rows are increasing in PostgreSQL.
control_room_current_status returns live values.
The old US Central VM was deleted after Singapore was verified.
```

See `docs/gcp_vm_operations.md` for the tunnel, DBeaver, monitoring, stop/start, and upgrade commands.

## Alerting Pause Point

Grafana alerting is paused at a safe point.

Completed:

```text
Alert rules are provisioned as code.
Gmail contact point is provisioned as code.
Notification policy routes project alerts to the Gmail contact point.
```

Not completed yet:

```text
Gmail SMTP is not enabled with a real Gmail App Password.
No real email alert has been sent yet.
```

This is safe to leave as-is. Grafana may show delivery errors because the current contact point uses the placeholder `grafana-alerts@example.invalid` while SMTP is disabled.

Resume command:

```bash
scripts/configure_gmail_alerts.sh
```

Use a Gmail App Password, not the normal Gmail password.

## DBeaver

DBeaver is installed and has a local PostgreSQL connection:

```text
Connection name: Kafka VM Postgres BI - Local
Host: localhost
Port: 5432
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

DBeaver also has a GCP Singapore tunnel connection:

```text
Connection name: Kafka VM Postgres BI - GCP Singapore Tunnel
Host: localhost
Port: 5433
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

This connection requires the PostgreSQL SSH tunnel from `docs/gcp_vm_operations.md`.

## Current Database Objects

Tables:

```text
machine_events_raw
monitoring_rules
```

Views:

```text
production_events
machine_status_minute
machine_alerts
dashboard_realtime_summary
control_room_window_15m
control_room_current_status
control_room_machine_status
control_room_alert_feed
```

## Useful Commands

Start:

```bash
scripts/start_services.sh
scripts/create_topics.sh
```

Check live services:

```bash
docker compose ps
```

Verify:

```bash
scripts/verify_postgres_counts.sh
scripts/query_postgres.sh "SELECT * FROM control_room_current_status;"
```

Reset:

```bash
scripts/reset_postgres_data.sh
```

Stop:

```bash
docker compose down
```

Open VM Grafana tunnel:

```bash
gcloud compute ssh kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a -- -N -L 3001:localhost:3000
```

Open VM PostgreSQL tunnel for DBeaver:

```bash
gcloud compute ssh kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a -- -N -L 5433:localhost:5432
```

Check VM resources:

```bash
gcloud compute ssh kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a --command 'free -h; df -h /; cd ~/Kafka-VM-Postgres-BI && sudo docker compose ps; sudo docker stats --no-stream'
```

## Important Decisions

- Use PostgreSQL as a Docker container, not a native Mac install.
- Use DBeaver for GUI SQL exploration.
- Use `scripts/query_postgres.sh` for fast terminal SQL.
- Use Grafana for the real-time dashboard.
- Keep Grafana dashboard definitions as code under `grafana/dashboards/`.
- Keep Grafana provisioning under `grafana/provisioning/`.
- Use one Kafka topic first: `machine_events`.
- Keep producer default at 10 events every 60 seconds.
- Start locally first, then run the same stack on the GCP VM.
- Use Singapore `e2-small` as the current low-cost demo VM.
- Upgrade to `e2-medium` only if Grafana, Kafka, PostgreSQL, or alerting becomes unstable.
- Keep Gmail SMTP disabled until we intentionally configure it in a local or VM-only `.env` file.

## Known Notes

- A simple Kafka smoke-test JSON message can be consumed by Kafka but skipped by the PostgreSQL consumer if it does not match the machine event contract.
- This is expected behavior.
- PostgreSQL data persists in the Docker named volume unless `docker compose down -v` is used.
- If SQL files change after PostgreSQL has already initialized, either apply SQL manually or recreate the volume.

## Next Step

Continue validating the Singapore VM dashboard and resource usage. Next optional build step is Gmail SMTP alert delivery on the VM after the dashboard and VM capacity remain stable.

Useful local dashboard sources:

```text
control_room_current_status
control_room_machine_status
control_room_alert_feed
machine_status_minute
dashboard_realtime_summary
```
