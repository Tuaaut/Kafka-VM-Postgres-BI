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
    product_sku TEXT,
    qr_code TEXT,
    print_result TEXT,
    vision_result TEXT,
    reject_flag BOOLEAN,
    reject_reason TEXT,
    position_error_mm NUMERIC(8, 3),
    grade_score NUMERIC(8, 2),
    machine_status TEXT,
    planned_speed_cpm NUMERIC(10, 2),
    actual_speed_cpm NUMERIC(10, 2),
    printhead_temp_c NUMERIC(8, 2),
    ink_level_pct NUMERIC(8, 2),
    ink_consumed_ml NUMERIC(10, 3),
    vibration_mm_s NUMERIC(8, 3),
    air_pressure_bar NUMERIC(8, 2),
    items_processed INTEGER,
    downtime_seconds INTEGER,
    log_id TEXT,
    log_timestamp TIMESTAMPTZ,
    fault_code TEXT,
    fault_description TEXT,
    severity TEXT,
    state_from TEXT,
    state_to TEXT,
    duration_seconds INTEGER,
    operator_id TEXT,
    event_time TIMESTAMPTZ NOT NULL,
    ingest_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload JSONB NOT NULL
);

ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS product_sku TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS qr_code TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS print_result TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS vision_result TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS reject_flag BOOLEAN;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS reject_reason TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS position_error_mm NUMERIC(8, 3);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS grade_score NUMERIC(8, 2);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS machine_status TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS planned_speed_cpm NUMERIC(10, 2);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS actual_speed_cpm NUMERIC(10, 2);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS printhead_temp_c NUMERIC(8, 2);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS ink_level_pct NUMERIC(8, 2);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS ink_consumed_ml NUMERIC(10, 3);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS vibration_mm_s NUMERIC(8, 3);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS air_pressure_bar NUMERIC(8, 2);
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS items_processed INTEGER;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS downtime_seconds INTEGER;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS log_id TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS log_timestamp TIMESTAMPTZ;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS fault_code TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS fault_description TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS severity TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS state_from TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS state_to TEXT;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS duration_seconds INTEGER;
ALTER TABLE machine_events_raw ADD COLUMN IF NOT EXISTS operator_id TEXT;

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
    product_sku,
    batch_id,
    qr_code,
    event_type,
    status,
    print_result,
    vision_result,
    reject_flag,
    reject_reason,
    fault_code,
    event_time,
    ingest_time
FROM machine_events_raw
WHERE event_type = 'PRINT_EVENT';

CREATE OR REPLACE VIEW machine_status_minute AS
SELECT
    DATE_TRUNC('minute', event_time) AS event_minute,
    machine_id,
    line_id,
    COUNT(*) AS event_count,
    AVG(COALESCE(printhead_temp_c, temperature)) AS avg_temperature,
    AVG(COALESCE(actual_speed_cpm, speed)) AS avg_speed,
    SUM(CASE WHEN print_result = 'FAILED' OR status IN ('FAILED', 'FAULTED') THEN 1 ELSE 0 END) AS failed_events,
    SUM(CASE WHEN status = 'FAULTED' OR severity IN ('HIGH', 'MEDIUM') THEN 1 ELSE 0 END) AS warning_events
FROM machine_events_raw
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW machine_alerts AS
SELECT
    event_id,
    machine_id,
    line_id,
    event_type,
    status,
    COALESCE(fault_code, error_code) AS error_code,
    COALESCE(printhead_temp_c, temperature) AS temperature,
    COALESCE(actual_speed_cpm, speed) AS speed,
    event_time,
    ingest_time,
    CASE
        WHEN print_result = 'FAILED' OR severity = 'HIGH' THEN 'critical'
        WHEN status = 'FAULTED' OR severity = 'MEDIUM' THEN 'warning'
        ELSE 'info'
    END AS severity
FROM machine_events_raw
WHERE print_result = 'FAILED'
   OR reject_flag IS TRUE
   OR status = 'FAULTED'
   OR event_type = 'MACHINE_LOG';

CREATE OR REPLACE VIEW dashboard_realtime_summary AS
SELECT
    COUNT(*) AS total_events,
    COUNT(*) FILTER (WHERE print_result = 'SUCCESS' OR status = 'RUNNING') AS successful_events,
    COUNT(*) FILTER (WHERE print_result = 'FAILED' OR status IN ('FAILED', 'FAULTED')) AS failed_events,
    COUNT(*) FILTER (WHERE status = 'FAULTED' OR severity IN ('HIGH', 'MEDIUM')) AS warning_events,
    ROUND(
        COUNT(*) FILTER (WHERE print_result = 'FAILED' OR status IN ('FAILED', 'FAULTED'))::NUMERIC / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS failure_rate_pct,
    MAX(event_time) AS latest_event_time,
    MAX(ingest_time) AS latest_ingest_time,
    ROUND(EXTRACT(EPOCH FROM (MAX(ingest_time) - MAX(event_time)))::NUMERIC, 2) AS latest_lag_seconds
FROM machine_events_raw;

\i /docker-entrypoint-initdb.d/02_control_room_model.sql
