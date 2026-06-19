CREATE TABLE IF NOT EXISTS machine_events_raw (
    event_id TEXT PRIMARY KEY,
    machine_id TEXT NOT NULL,
    line_id TEXT,
    event_type TEXT NOT NULL,
    status TEXT NOT NULL,
    error_code TEXT,
    temperature NUMERIC(8, 2),
    speed NUMERIC(8, 2),
    batch_id TEXT,
    qr_code_id TEXT,
    product_code TEXT,
    event_time TIMESTAMPTZ NOT NULL,
    ingest_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload JSONB NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_machine_events_raw_event_time
    ON machine_events_raw (event_time DESC);

CREATE INDEX IF NOT EXISTS idx_machine_events_raw_machine_event_time
    ON machine_events_raw (machine_id, event_time DESC);

CREATE INDEX IF NOT EXISTS idx_machine_events_raw_event_type
    ON machine_events_raw (event_type);

CREATE OR REPLACE VIEW production_events AS
SELECT
    event_id,
    machine_id,
    line_id,
    product_code,
    batch_id,
    qr_code_id,
    event_type,
    status,
    error_code,
    event_time,
    ingest_time
FROM machine_events_raw
WHERE event_type IN ('print_completed', 'print_failed', 'production_counter');

CREATE OR REPLACE VIEW machine_status_minute AS
SELECT
    DATE_TRUNC('minute', event_time) AS event_minute,
    machine_id,
    line_id,
    COUNT(*) AS event_count,
    AVG(temperature) AS avg_temperature,
    AVG(speed) AS avg_speed,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_events,
    SUM(CASE WHEN status = 'warning' THEN 1 ELSE 0 END) AS warning_events
FROM machine_events_raw
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW machine_alerts AS
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
        WHEN status = 'failed' THEN 'critical'
        WHEN status = 'warning' THEN 'warning'
        ELSE 'info'
    END AS severity
FROM machine_events_raw
WHERE status IN ('failed', 'warning')
   OR event_type IN ('machine_warning', 'machine_fault');

CREATE OR REPLACE VIEW dashboard_realtime_summary AS
SELECT
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE status = 'success') AS successful_events,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_events,
    COUNT(*) FILTER (WHERE status = 'warning') AS warning_events,
    ROUND(
        COUNT(*) FILTER (WHERE status = 'failed')::NUMERIC / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS failure_rate_pct,
    MAX(event_time) AS latest_event_time,
    MAX(ingest_time) AS latest_ingest_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(ingest_time) - MAX(event_time)))::NUMERIC, 2) AS latest_lag_seconds
FROM machine_events_raw;

\i /docker-entrypoint-initdb.d/02_control_room_model.sql
