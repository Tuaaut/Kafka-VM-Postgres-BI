-- Grafana dashboard starter queries for PostgreSQL.
-- These queries back the local control-room dashboard provisioned in grafana/dashboards/.

-- 1. Real-time KPI summary
SELECT *
FROM dashboard_realtime_summary;

-- 1a. Control-room status tile
SELECT *
FROM control_room_current_status;

-- 1b. Machine status board
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

-- 1c. Live alert feed
SELECT *
FROM control_room_alert_feed
ORDER BY event_time DESC
LIMIT 100;

-- 2. Events per minute
SELECT
    DATE_TRUNC('minute', event_time) AS event_minute,
    COUNT(*) AS event_count,
    COUNT(*) FILTER (WHERE print_result = 'FAILED' OR status IN ('FAILED', 'FAULTED')) AS failed_events,
    COUNT(*) FILTER (WHERE status = 'FAULTED' OR severity IN ('HIGH', 'MEDIUM')) AS warning_events
FROM machine_events_raw
GROUP BY 1
ORDER BY 1 DESC;

-- 3. Machine health by minute
SELECT *
FROM machine_status_minute
ORDER BY event_minute DESC, machine_id;

-- 4. Latest alerts
SELECT *
FROM machine_alerts
ORDER BY event_time DESC
LIMIT 100;

-- 5. Production events by machine
SELECT
    machine_id,
    line_id,
    COUNT(*) AS production_events,
    COUNT(*) FILTER (WHERE print_result = 'SUCCESS') AS success_count,
    COUNT(*) FILTER (WHERE print_result = 'FAILED' OR status = 'FAILED') AS failed_count,
    MAX(event_time) AS latest_event_time
FROM production_events
GROUP BY machine_id, line_id
ORDER BY machine_id, line_id;
