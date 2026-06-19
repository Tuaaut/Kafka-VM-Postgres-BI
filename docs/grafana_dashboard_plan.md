# Grafana Dashboard Plan

Grafana is now the recommended dashboard layer for this project.

Why:

```text
Kafka is operational streaming.
Grafana is operational monitoring.
PostgreSQL is the live serving layer.
```

This is a natural fit for a Kafka demo because Grafana is lighter, free to run locally, alert-friendly, shareable, and dashboard-as-code friendly.

## Local Access

URL:

```text
http://localhost:3000
```

Default login:

```text
User: admin
Password: admin
```

For a real shared deployment, change the password before exposing Grafana to other users.

## GCP VM Access

The Singapore VM dashboard is accessed through an SSH tunnel:

```text
http://localhost:3001
```

This points to Grafana on `kafka-postgres-bi-sg` in `asia-southeast1-a`. See `docs/gcp_vm_operations.md` for tunnel and sharing commands.

## Dashboard-As-Code Structure

```text
grafana/
  provisioning/
    datasources/
      postgres.yml
    dashboards/
      dashboards.yml
    alerting/
      kafka_alert_rules.yml
  dashboards/
    kafka_control_room.json
```

Meaning:

- `postgres.yml` defines the PostgreSQL connection.
- `dashboards.yml` tells Grafana where to load dashboard JSON files.
- `kafka_alert_rules.yml` defines local Grafana alert rules.
- `kafka_control_room.json` defines the dashboard panels.

This lets us build and manage the monitoring dashboard as code.

## Data Source

Grafana connects to PostgreSQL from inside Docker:

```text
Host: postgres:5432
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

Do not use `localhost` inside Grafana because Grafana runs in its own container. `localhost` would point to the Grafana container, not the PostgreSQL container.

## First Dashboard

Dashboard name:

```text
Kafka Machine Monitoring Control Room
```

Purpose:

```text
Show the live state of the Kafka to PostgreSQL monitoring pipeline.
```

Recommended layout:

```text
Top row:
    Plant state
    Total events
    Failure rate %
    Critical 15m
    Ingest lag

Middle:
    Events per minute
    Machine board

Production line row:
    Production line KPI
    Production line event flow

Bottom:
    Alert feed with suggested action
```

## Panel Mapping

| Panel | Source | Query / View | Purpose |
| --- | --- | --- | --- |
| Plant State | PostgreSQL | `control_room_current_status` | Current operating state. |
| Events 15m | PostgreSQL | `control_room_current_status.total_events` | Current event flow. |
| Failure Rate % | PostgreSQL | `control_room_current_status.failure_rate_pct` | Quality/risk signal. |
| Critical 15m | PostgreSQL | `control_room_alert_feed` | Current alert pressure. |
| Ingest Lag | PostgreSQL | `control_room_current_status.latest_lag_seconds` | Pipeline freshness. |
| Event Flow Per Minute | PostgreSQL | `machine_status_minute` | Event trend. |
| Machine Board | PostgreSQL | `control_room_machine_status` | Which machine needs attention. |
| Production Line KPI 15m | PostgreSQL | `machine_events_raw`, `control_room_alert_feed` | Compare L01/L02 status, failures, warnings, temperature, and critical pressure. |
| Production Line Event Flow | PostgreSQL | `machine_events_raw` | Compare event volume and failed events by production line. |
| Alert Feed 60m | PostgreSQL | `control_room_alert_feed` | Recent warning/critical events with suggested action. |

Dashboard filters:

```text
Machine
Line
```

These filters should apply to the top cards, event trend, machine board, and alert feed.

## Refresh Cadence

Recommended Grafana refresh:

```text
30 seconds
```

Producer cadence:

```text
10 events every 60 seconds
```

This means Grafana may refresh twice between producer batches. That is fine for the demo.

## Sharing And Permissions

Local demo:

```text
admin/admin
```

Shared VM demo:

```text
Create viewer users.
Put dashboards in a folder.
Give viewers read-only access.
Keep editor/admin access limited.
```

Grafana OSS supports basic users, teams, folders, and dashboard permissions. For this project, that is enough.

## Alerting Direction

Grafana now has local alert rules provisioned from code.

Current local rules:

- `Plant State Critical`
- `Ingest Lag Above 300s`

These rules are provisioned as code. A Gmail email contact point is also provisioned, but real email sending requires Gmail SMTP values in a secure local or VM-only `.env` file.

Gmail setup helper:

```bash
scripts/configure_gmail_alerts.sh
```

Next alerting candidates:

- Failure rate is above 10%.
- Any machine status is `CRITICAL`.
- Critical alert count is above a chosen threshold.
- No events received for more than one producer cycle.

## Demo Flow

1. Start services with `scripts/start_services.sh`.
2. Create Kafka topic with `scripts/create_topics.sh`.
3. Open Grafana at `http://localhost:3000`.
4. Confirm the PostgreSQL data source is provisioned.
5. Open `Kafka Machine Monitoring Control Room`.
6. Run the consumer.
7. Run the producer.
8. Watch status, trend, machine board, and alert feed update.

For the GCP Singapore VM, open Grafana through the SSH tunnel at `http://localhost:3001`. See `docs/gcp_vm_operations.md`.

## Future Improvement Ideas

- Add a second dashboard for machine detail.
- Add a dashboard variable for `machine_id`.
- Move Gmail SMTP values to a secure VM-only environment file or secret pattern before sending real email alerts from GCP.
- Add screenshots to `docs/screenshots/`.
- Add a read-only demo user.
- Add a public/shared access pattern only after GCP networking is secure.
