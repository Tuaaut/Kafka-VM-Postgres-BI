# Control-Room KPI Definitions

This project uses PostgreSQL as a real-time monitoring semantic layer, not as a historical KPI mart.

The main dashboard should prioritize:

```text
current status
freshness
machine risk
failure/warning activity
alert feed
```

## Primary SQL Objects

```text
dashboard_realtime_summary
control_room_current_status
control_room_machine_status
control_room_alert_feed
machine_status_minute
machine_alerts
monitoring_rules
```

## Top-Level Status KPIs

### Control Room Status

Source:

```text
control_room_current_status.control_room_status
```

Values:

- `NORMAL`
- `WARNING`
- `CRITICAL`
- `NO_DATA`

Business meaning:

```text
The current operational state of the monitored production stream.
```

Recommended visual:

```text
Large status card with conditional color.
```

### Latest Event Time

Source:

```text
control_room_current_status.latest_event_time
```

Business meaning:

```text
The newest machine event currently visible to PostgreSQL.
```

Recommended visual:

```text
Card or small timestamp label near the status card.
```

### Latest Lag Seconds

Source:

```text
control_room_current_status.latest_lag_seconds
```

Definition:

```text
latest_ingest_time - latest_event_time
```

Business meaning:

```text
How delayed the PostgreSQL ingestion path is compared with event time.
```

Thresholds:

- Warning at 120 seconds.
- Critical at 300 seconds.

## Production Flow KPIs

### Total Events

Source:

```text
dashboard_realtime_summary.total_events
control_room_current_status.total_events
```

Definition:

```text
COUNT(*) from machine_events_raw
```

Business meaning:

```text
How many machine events have been received.
```

### Successful Events

Source:

```text
dashboard_realtime_summary.successful_events
```

Definition:

```text
COUNT(*) WHERE print_result = 'SUCCESS' OR status = 'RUNNING'
```

### Failed Events

Source:

```text
dashboard_realtime_summary.failed_events
```

Definition:

```text
COUNT(*) WHERE print_result = 'FAILED' OR status IN ('FAILED', 'FAULTED')
```

### Warning Events

Source:

```text
dashboard_realtime_summary.warning_events
```

Definition:

```text
COUNT(*) WHERE status = 'FAULTED' OR severity IN ('HIGH', 'MEDIUM')
```

## Quality KPIs

### Failure Rate %

Source:

```text
dashboard_realtime_summary.failure_rate_pct
control_room_current_status.failure_rate_pct
```

Definition:

```text
failed_events / total_events * 100
```

Thresholds:

- Warning at 5%.
- Critical at 10%.

Business meaning:

```text
The share of recent machine or production events that failed.
```

### Print Completed Count

Source:

```text
production_events
```

Definition:

```text
COUNT(*) WHERE event_type = 'print_completed'
```

### Print Failed Count

Source:

```text
production_events
```

Definition:

```text
COUNT(*) WHERE event_type = 'PRINT_EVENT' AND print_result = 'FAILED'
```

### Error Count

Source:

```text
machine_events_raw.error_code
```

Definition:

```text
COUNT(*) WHERE error_code IS NOT NULL
```

## Machine Health KPIs

### Machine Status

Source:

```text
control_room_machine_status.machine_status
```

Values:

- `NORMAL`
- `WARNING`
- `CRITICAL`

Recommended visual:

```text
Machine grid or table with conditional formatting.
```

### Average Temperature

Sources:

```text
control_room_current_status.avg_temperature
control_room_machine_status.avg_temperature_15m
machine_status_minute.avg_temperature
```

Thresholds:

- Warning at 75 C.
- Critical at 85 C.

### Average Speed

Sources:

```text
control_room_current_status.avg_speed
control_room_machine_status.avg_speed_15m
machine_status_minute.avg_speed
```

Business meaning:

```text
Current or recent production speed signal by machine or overall stream.
```

### Machine Failed Events 15m

Source:

```text
control_room_machine_status.failed_events_15m
```

Machine-level critical rule:

```text
failed_events_15m >= 3
```

### Machine Warning Events 15m

Source:

```text
control_room_machine_status.warning_events_15m
```

Machine-level warning rule:

```text
warning_events_15m >= 3
```

## Alert KPIs

### Alert Severity

Source:

```text
control_room_alert_feed.alert_severity
```

Values:

- `CRITICAL`
- `WARNING`
- `INFO`

### Alert Reason

Source:

```text
control_room_alert_feed.alert_reason
```

Reasons:

- Failed machine or production event.
- Machine warning event.
- Critical temperature threshold breached.
- Warning temperature threshold breached.
- Informational event.

### Active Alert Count

Source:

```text
control_room_alert_feed
```

Definition:

```text
COUNT(*) by alert_severity in the last 60 minutes
```

Recommended visual:

```text
Stacked bar or severity cards.
```

## Time Windows

Current monitoring window:

```text
15 minutes
```

Alert feed window:

```text
60 minutes
```

Minute trend view:

```text
machine_status_minute
```

## Important Difference From Historical KPI Projects

Historical analytics asks:

```text
What happened over days, weeks, or months?
```

This real-time monitoring project asks:

```text
What needs attention now?
```

So the control-room dashboard should not start with deep historical trend pages. It should start with current state, machine risk, and alerts.
