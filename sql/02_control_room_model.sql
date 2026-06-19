CREATE TABLE IF NOT EXISTS monitoring_rules (
    rule_id TEXT PRIMARY KEY,
    rule_name TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    warning_threshold NUMERIC(12, 2),
    critical_threshold NUMERIC(12, 2),
    comparison_operator TEXT NOT NULL DEFAULT '>=',
    lookback_minutes INTEGER NOT NULL DEFAULT 15,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    rule_description TEXT
);

INSERT INTO monitoring_rules (
    rule_id,
    rule_name,
    metric_name,
    warning_threshold,
    critical_threshold,
    comparison_operator,
    lookback_minutes,
    rule_description
)
VALUES
    (
        'failure_rate_15m',
        'Failure rate spike',
        'failure_rate_pct',
        5,
        10,
        '>=',
        15,
        'Failure rate across the last 15 minutes is higher than expected.'
    ),
    (
        'warning_count_15m',
        'Warning event spike',
        'warning_events',
        5,
        10,
        '>=',
        15,
        'Machine warning volume is higher than expected.'
    ),
    (
        'temperature_15m',
        'High average temperature',
        'avg_temperature',
        75,
        85,
        '>=',
        15,
        'Average machine temperature is outside the safe monitoring range.'
    ),
    (
        'event_lag_seconds',
        'Event ingest lag',
        'latest_lag_seconds',
        120,
        300,
        '>=',
        15,
        'Consumer ingest lag suggests the real-time feed may be delayed.'
    )
ON CONFLICT (rule_id) DO UPDATE SET
    rule_name = EXCLUDED.rule_name,
    metric_name = EXCLUDED.metric_name,
    warning_threshold = EXCLUDED.warning_threshold,
    critical_threshold = EXCLUDED.critical_threshold,
    comparison_operator = EXCLUDED.comparison_operator,
    lookback_minutes = EXCLUDED.lookback_minutes,
    is_active = EXCLUDED.is_active,
    rule_description = EXCLUDED.rule_description;

CREATE OR REPLACE VIEW control_room_window_15m AS
SELECT
    NOW() AS snapshot_time,
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE status = 'success') AS successful_events,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_events,
    COUNT(*) FILTER (WHERE status = 'warning') AS warning_events,
    ROUND(
        COUNT(*) FILTER (WHERE status = 'failed')::NUMERIC / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS failure_rate_pct,
    ROUND(AVG(temperature), 2) AS avg_temperature,
    ROUND(AVG(speed), 2) AS avg_speed,
    MAX(event_time) AS latest_event_time,
    MAX(ingest_time) AS latest_ingest_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(ingest_time) - MAX(event_time)))::NUMERIC, 2) AS latest_lag_seconds
FROM machine_events_raw
WHERE event_time >= NOW() - INTERVAL '15 minutes';

CREATE OR REPLACE VIEW control_room_current_status AS
WITH metrics AS (
    SELECT *
    FROM control_room_window_15m
),
scored AS (
    SELECT
        snapshot_time,
        total_events,
        successful_events,
        failed_events,
        warning_events,
        failure_rate_pct,
        avg_temperature,
        avg_speed,
        latest_event_time,
        latest_ingest_time,
        latest_lag_seconds,
        CASE
            WHEN total_events = 0 THEN 'NO_DATA'
            WHEN failure_rate_pct >= 10
              OR warning_events >= 10
              OR avg_temperature >= 85
              OR latest_lag_seconds >= 300 THEN 'CRITICAL'
            WHEN failure_rate_pct >= 5
              OR warning_events >= 5
              OR avg_temperature >= 75
              OR latest_lag_seconds >= 120 THEN 'WARNING'
            ELSE 'NORMAL'
        END AS control_room_status
    FROM metrics
)
SELECT *
FROM scored;

CREATE OR REPLACE VIEW control_room_machine_status AS
SELECT
    machine_id,
    line_id,
    COUNT(*) AS total_events_15m,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_events_15m,
    COUNT(*) FILTER (WHERE status = 'warning') AS warning_events_15m,
    ROUND(AVG(temperature), 2) AS avg_temperature_15m,
    ROUND(AVG(speed), 2) AS avg_speed_15m,
    MAX(event_time) AS latest_event_time,
    CASE
        WHEN COUNT(*) = 0 THEN 'NO_DATA'
        WHEN COUNT(*) FILTER (WHERE status = 'failed') >= 3
          OR ROUND(AVG(temperature), 2) >= 85 THEN 'CRITICAL'
        WHEN COUNT(*) FILTER (WHERE status = 'warning') >= 3
          OR ROUND(AVG(temperature), 2) >= 75 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS machine_status
FROM machine_events_raw
WHERE event_time >= NOW() - INTERVAL '15 minutes'
GROUP BY machine_id, line_id;

CREATE OR REPLACE VIEW control_room_alert_feed AS
SELECT
    event_id,
    machine_id,
    line_id,
    event_type,
    status,
    error_code,
    temperature,
    speed,
    event_time,
    ingest_time,
    CASE
        WHEN status = 'failed' OR temperature >= 85 THEN 'CRITICAL'
        WHEN status = 'warning' OR temperature >= 75 THEN 'WARNING'
        ELSE 'INFO'
    END AS alert_severity,
    CASE
        WHEN status = 'failed' THEN 'Failed machine or production event'
        WHEN status = 'warning' THEN 'Machine warning event'
        WHEN temperature >= 85 THEN 'Critical temperature threshold breached'
        WHEN temperature >= 75 THEN 'Warning temperature threshold breached'
        ELSE 'Informational event'
    END AS alert_reason
FROM machine_events_raw
WHERE event_time >= NOW() - INTERVAL '60 minutes'
  AND (
      status IN ('failed', 'warning')
      OR temperature >= 75
      OR event_type IN ('machine_warning', 'machine_fault')
  );
