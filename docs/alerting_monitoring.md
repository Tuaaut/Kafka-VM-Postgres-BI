# Alerting and Monitoring

This project separates live operational monitoring from historical analytics.

The monitoring layer is designed like a control room:

```text
What is happening now?
Which machines need attention?
Are events still flowing?
Is the consumer delayed?
Are failures, warnings, or extreme readings increasing?
```

## Current Status

PostgreSQL monitoring views are created, tested locally, and now running on the Singapore GCP VM.

Latest local test result:

```text
rows_in_raw = 60
control_room_status = CRITICAL
failure_rate_pct = 10.00
latest_lag_seconds = about 0.02
```

This result is expected because the test event mix included enough failed events to trigger the critical threshold.

Current GCP access uses SSH tunnels:

```text
Grafana: http://localhost:3001
PostgreSQL/DBeaver: localhost:5433
```

## Monitoring Architecture

```text
Python producer
→ Kafka topic machine_events
→ Python consumer
→ PostgreSQL table machine_events_raw
→ PostgreSQL control-room views
→ Grafana
```

Kafka is the event backbone. PostgreSQL is the operational serving layer. Grafana reads the current PostgreSQL state.

## Monitoring Coverage

The first version monitors:

- Producer is generating events.
- Kafka topic is available.
- Consumer is receiving valid Kafka messages.
- PostgreSQL row counts are increasing.
- Latest event timestamp is recent.
- Ingest lag is low.
- Failure rate is under threshold.
- Warning and fault events are visible.
- Machine-level status is ranked as normal, warning, or critical.
- Alert feed highlights outlier, extreme, or suspicious activity.
- Grafana can query PostgreSQL through its provisioned PostgreSQL datasource.
- Grafana local alert rules are provisioned as code.

## Main SQL Objects

```text
monitoring_rules
control_room_window_15m
control_room_current_status
control_room_machine_status
control_room_alert_feed
machine_alerts
dashboard_realtime_summary
```

## Control-Room Status

View:

```sql
SELECT *
FROM control_room_current_status;
```

Status values:

- `NORMAL`: events are flowing and key metrics are under warning thresholds.
- `WARNING`: at least one monitored metric is elevated.
- `CRITICAL`: at least one monitored metric breached a critical threshold.
- `NO_DATA`: no event exists in the current 15-minute monitoring window.

Default current-window rules:

| Metric | Warning | Critical | Meaning |
| --- | ---: | ---: | --- |
| `failure_rate_pct` | 5% | 10% | Failed events are increasing. |
| `warning_events` | 5 | 10 | Warning volume is increasing. |
| `avg_temperature` | 75 C | 85 C | Machine temperature is elevated. |
| `latest_lag_seconds` | 120 sec | 300 sec | Consumer or ingest path may be delayed. |

## Machine Status Board

View:

```sql
SELECT *
FROM control_room_machine_status
ORDER BY
    CASE machine_status
        WHEN 'CRITICAL' THEN 1
        WHEN 'WARNING' THEN 2
        WHEN 'NORMAL' THEN 3
        ELSE 4
    END,
    machine_id;
```

Purpose:

- Show which machine needs attention first.
- Separate machine-level problems from overall factory status.
- Give Grafana a compact table for conditional formatting.

Machine rules:

- `CRITICAL` when a machine has at least 3 failed events in 15 minutes or average temperature is at least 85 C.
- `WARNING` when a machine has at least 3 warning events in 15 minutes or average temperature is at least 75 C.
- `NORMAL` when none of the warning or critical rules are breached.

## Alert Feed

View:

```sql
SELECT *
FROM control_room_alert_feed
ORDER BY event_time DESC
LIMIT 100;
```

Purpose:

- Show recent events that deserve human attention.
- Support a control-room table visual in Grafana.
- Keep alert reason and severity readable.

Included events:

- `status = 'failed'`
- `status = 'warning'`
- `temperature >= 75`
- `event_type IN ('machine_warning', 'machine_fault')`

Alert severity:

- `CRITICAL`: failed event or temperature at least 85 C.
- `WARNING`: warning event or temperature at least 75 C.
- `INFO`: retained only for informational edge cases.

## Grafana Alert Rules

Local Grafana alert rules are now provisioned from:

```text
grafana/provisioning/alerting/kafka_alert_rules.yml
```

Grafana loads this file when the Grafana container starts.

Current rule group:

```text
Folder: Kafka Monitoring
Group: kafka_control_room
Evaluation interval: 30 seconds
Pending period: 60 seconds
```

Current local rules:

| Rule | UID | Trigger | Severity |
| --- | --- | --- | --- |
| Plant State Critical | `kafka_plant_state_critical` | Current 15-minute control-room window crosses a critical threshold. | `critical` |
| Ingest Lag Above 300s | `kafka_ingest_lag_high` | Latest ingest lag in the 15-minute window is above 300 seconds. | `warning` |

Plant State Critical uses the same operating logic as the control-room status:

- Failure rate is at least 10%.
- Warning event count is at least 10.
- Average temperature is at least 85 C.
- Latest ingest lag is at least 300 seconds.

Both rules use:

```text
noDataState: OK
execErrState: Error
```

This means an empty demo window should not create noise, but query/runtime problems should still be visible.

Local verification commands:

```bash
docker compose up -d --force-recreate grafana
docker logs kafka_vm_grafana --since 2m | grep -i provisioning
curl -u admin:admin http://localhost:3000/api/v1/provisioning/alert-rules
```

## Gmail Email Contact Point

A Grafana email contact point is provisioned from:

```text
grafana/provisioning/alerting/gmail_contact_point.yml
```

Current contact point:

```text
Name: kafka-gmail-email
Type: Email
Default placeholder recipient: grafana-alerts@example.invalid
```

Current notification policy:

```text
Default receiver: kafka-gmail-email
Project route: project = kafka_vm_postgres_bi
```

The contact point and policy are loaded locally, but Gmail SMTP is disabled until `.env` contains real Gmail SMTP values.

Use this helper to configure Gmail locally:

```bash
scripts/configure_gmail_alerts.sh
```

The helper writes only to local `.env`, which is ignored by Git.

Gmail requirement:

```text
Use a Gmail App Password, not the normal Gmail account password.
```

After configuration, verify:

```bash
curl -u admin:admin http://localhost:3000/api/v1/provisioning/contact-points
curl -u admin:admin http://localhost:3000/api/v1/provisioning/policies
```

Visual check in Grafana:

```text
Alerting -> Contact points
Alerting -> Notification policies
```

Expected local behavior before Gmail SMTP is configured:

```text
Grafana may show delivery errors because the active demo alert is routed to a placeholder email while SMTP is disabled.
```

Expected behavior after Gmail SMTP is configured:

```text
Active firing alerts can send email to the configured Gmail recipient.
```

## Operational Health Queries

Event count:

```sql
SELECT COUNT(*) AS total_events
FROM machine_events_raw;
```

Latest event:

```sql
SELECT
    MAX(event_time) AS latest_event_time,
    MAX(ingest_time) AS latest_ingest_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(ingest_time) - MAX(event_time)))::NUMERIC, 2) AS latest_lag_seconds
FROM machine_events_raw;
```

Event mix:

```sql
SELECT event_type, status, COUNT(*) AS event_count
FROM machine_events_raw
GROUP BY event_type, status
ORDER BY event_count DESC;
```

Alerts by severity:

```sql
SELECT alert_severity, COUNT(*) AS alert_count
FROM control_room_alert_feed
GROUP BY alert_severity
ORDER BY alert_count DESC;
```

## Scheduling Note

Kafka is not the scheduler in this demo. Kafka stays available, while the producer controls the event cadence.

Default demo cycle:

```text
Every 60 seconds
→ producer emits 10 machine events
→ Kafka stores the messages
→ consumer writes them to PostgreSQL
→ Grafana reads the current views
```

This keeps the system live without making the VM unnecessarily expensive.

## Future Alerting Options

Current local setup:

```text
PostgreSQL alert views
→ Grafana dashboard alert feed
→ Grafana local alert rules
```

Later options:

```text
Scheduled SQL check
→ email
```

```text
Python alert service
→ Teams / Slack webhook
```

```text
Incident workflow
→ ServiceNow / Jira / PagerDuty
```

Keep Gmail SMTP disabled until we intentionally configure it. For the current GCP VM, use a secure VM-only `.env` file or secret manager pattern before sending real email alerts.
