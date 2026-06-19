# Database Model

PostgreSQL is the operational serving layer for this project.

It stores recent machine events and exposes views for Grafana. The model is intentionally designed for monitoring first, not long-term analytics first.

PostgreSQL is kept intentionally. It is not just a middleman:

```text
Kafka carries events.
PostgreSQL serves queryable operational state.
Grafana visualizes and alerts on that state.
```

This lets the dashboard be cross-checked through DBeaver or terminal SQL, which is important for trust in the control-room view.

## Model Layers

```text
Raw event table
→ operational views
→ control-room views
→ Grafana dashboard
```

## Raw Table

Table:

```text
machine_events_raw
```

Purpose:

```text
Store every valid machine event consumed from Kafka.
```

Important columns:

| Column | Purpose |
| --- | --- |
| `event_id` | Unique event identifier and primary key. |
| `machine_id` | Machine that emitted the event. |
| `line_id` | Production line. |
| `event_type` | Event category such as print completed, failed, warning, or counter. |
| `status` | Event status such as success, failed, or warning. |
| `error_code` | Optional machine or production error code. |
| `temperature` | Machine temperature signal. |
| `speed` | Machine speed signal. |
| `batch_id` | Production batch identifier. |
| `qr_code_id` | QR code identifier for print events. |
| `product_code` | Product or SKU signal. |
| `event_time` | Time the event happened. |
| `ingest_time` | Time PostgreSQL inserted the event. |
| `payload` | Full original JSON event. |

Indexes:

```text
event_time DESC
machine_id, event_time DESC
event_type
```

## Event Contract

Required fields:

```text
event_id
machine_id
event_type
status
event_time
```

Recommended optional fields:

```text
line_id
error_code
temperature
speed
batch_id
qr_code_id
product_code
```

The consumer skips invalid messages that are missing required fields. This lets Kafka smoke tests happen without breaking the database writer.

## Operational Views

### production_events

Purpose:

```text
Expose production and QR-printing related events.
```

Included event types:

```text
print_completed
print_failed
production_counter
```

Use for:

- Production count.
- Print completed count.
- Print failed count.
- Product or batch drilldown.

### machine_status_minute

Purpose:

```text
Aggregate machine health by minute.
```

Metrics:

- Event count.
- Average temperature.
- Average speed.
- Failed events.
- Warning events.

Use for:

- Time trend visuals.
- Machine performance trend.
- Failure and warning movement over time.

### machine_alerts

Purpose:

```text
Expose failed and warning events with a simple severity label.
```

Use for:

- Basic alert table.
- Early dashboard version.
- Comparing with the richer `control_room_alert_feed`.

### dashboard_realtime_summary

Purpose:

```text
Simple all-time operational summary.
```

Metrics:

- Total events.
- Successful events.
- Failed events.
- Warning events.
- Failure rate.
- Latest event time.
- Latest ingest time.
- Latest lag seconds.

Use for:

- Starter KPI cards.
- Quick terminal verification.
- Simple Grafana page before the full control-room page.

## Control-Room Model

### monitoring_rules

Purpose:

```text
Reference table for monitoring rule definitions and thresholds.
```

Current rules:

| Rule | Metric | Warning | Critical | Window |
| --- | --- | ---: | ---: | ---: |
| Failure rate spike | `failure_rate_pct` | 5 | 10 | 15 min |
| Warning event spike | `warning_events` | 5 | 10 | 15 min |
| High average temperature | `avg_temperature` | 75 | 85 | 15 min |
| Event ingest lag | `latest_lag_seconds` | 120 | 300 | 15 min |

Note:

```text
The table documents thresholds. Current SQL views encode the logic directly.
```

### control_room_window_15m

Purpose:

```text
Calculate current 15-minute metrics.
```

Use for:

- Debugging.
- Base metrics for status scoring.

### control_room_current_status

Purpose:

```text
Return one current operational status row for the dashboard.
```

Status logic:

```text
NO_DATA  = no events in current 15-minute window
CRITICAL = failure rate >= 10%, warning events >= 10, avg temperature >= 85 C, or lag >= 300 sec
WARNING  = failure rate >= 5%, warning events >= 5, avg temperature >= 75 C, or lag >= 120 sec
NORMAL   = data exists and no warning/critical rule is breached
```

Use for:

- Main dashboard status card.
- Event freshness cards.
- Failure rate cards.

### control_room_machine_status

Purpose:

```text
Return one row per machine for the current 15-minute window.
```

Metrics:

- Total events by machine.
- Failed events by machine.
- Warning events by machine.
- Average temperature by machine.
- Average speed by machine.
- Latest event time by machine.
- Machine status.

Use for:

- Machine status grid.
- Conditional formatting.
- Ranking machines by severity.

### control_room_alert_feed

Purpose:

```text
Return recent warning, failed, high-temperature, or suspicious events.
```

Window:

```text
60 minutes
```

Use for:

- Live alert table.
- Incident review.
- Demo of suspicious activity monitoring.

## Grafana Recommended Tables

Start with:

```text
control_room_current_status
control_room_machine_status
control_room_alert_feed
machine_status_minute
dashboard_realtime_summary
```

Optional later:

```text
production_events
machine_alerts
machine_events_raw
```

Avoid starting Grafana from `machine_events_raw` unless a detail table is needed. The views are cleaner for live PostgreSQL dashboard queries.

## Useful SQL

Current status:

```sql
SELECT *
FROM control_room_current_status;
```

Machine board:

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

Alert feed:

```sql
SELECT *
FROM control_room_alert_feed
ORDER BY event_time DESC
LIMIT 100;
```

Events by minute:

```sql
SELECT
    DATE_TRUNC('minute', event_time) AS event_minute,
    COUNT(*) AS event_count,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_events,
    COUNT(*) FILTER (WHERE status = 'warning') AS warning_events
FROM machine_events_raw
GROUP BY 1
ORDER BY 1 DESC;
```

## Model Evolution Ideas

Later improvements:

- Add retention or archive strategy for old raw events.
- Add materialized views if Grafana queries become slow.
- Make `monitoring_rules` fully dynamic.
- Add machine dimension table.
- Add production line dimension table.
- Add alert acknowledgment table.
- Add alert owner and resolution status.
