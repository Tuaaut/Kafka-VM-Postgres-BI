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

PostgreSQL monitoring views are created, tested locally, and running on the Singapore GCP VM.

Gmail alert delivery is configured and verified.

Latest local test result:

```text
rows_in_raw = 60
control_room_status = CRITICAL
failure_rate_pct = 10.00
latest_lag_seconds = about 0.02
```

This result is expected because the test event mix included enough failed events to trigger the critical threshold.

Current dashboard access modes:

```text
Local Grafana: http://localhost:3000
Public VM Grafana base URL for alert links: http://136.110.54.120:3000
Public dashboard path: http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room
SSH tunnel fallback: http://localhost:3001
PostgreSQL/DBeaver: localhost:5433
```

The public VM URL only works while the VM is running and Grafana is exposed. The SSH tunnel URL only works from the Mac where the tunnel is open.

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
- Grafana alert rules are provisioned as code.
- Grafana Gmail email contact point is provisioned as code.
- Gmail SMTP is configured in local `.env` and real alert email delivery has been verified.

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

- `print_result = 'FAILED'`
- `reject_flag = true`
- `status = 'FAULTED'`
- `severity IN ('HIGH', 'MEDIUM')`
- `printhead_temp_c >= 75`
- `event_type = 'MACHINE_LOG'`

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
Recipient: pattaratua@gmail.com
```

Current notification policy:

```text
Default receiver: kafka-gmail-email
Project route: project = kafka_vm_postgres_bi
```

The contact point and policy are loaded by Grafana provisioning.

Current Gmail SMTP status:

```text
Configured: yes
Sender: pattaratua@gmail.com
Recipient: pattaratua@gmail.com
Credential storage: local .env only
Git status: .env is ignored
Real SMTP test: passed
Real Grafana alert email test: passed
```

Important security rule:

```text
Do not write the Gmail App Password into Markdown docs, screenshots, Git commits, or shared messages.
```

Use this helper only if SMTP needs to be reconfigured:

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

Expected behavior:

```text
Active firing alerts are sent to the Gmail recipient.
Resolved alerts may also send a resolved message because disableResolveMessage is false.
```

## Alert Email Message Format

The original Grafana default email showed raw evaluator values such as `A=1`, `B=1`, and `C=1`. That proved the rule fired, but it was too technical for operations users.

The contact point now uses a custom email subject and body.

Subject pattern:

```text
Kafka Monitoring: [FIRING] Plant State Critical critical
```

Body includes:

- Alert status.
- Alert group.
- Severity.
- Summary.
- Impact.
- Action plan.
- Dashboard link.
- Silence link.
- Resolution note when the alert resolves.

Current `Plant State Critical` action plan:

```text
1. Open the Grafana control-room dashboard and confirm the Plant State panel.
2. Check the latest alert feed to identify the affected production line, machine, and reason.
3. Notify the responsible technician or production support owner to inspect the line and take action as soon as possible.
4. Keep the incident open until the dashboard returns to NORMAL or the root cause is confirmed.
```

This wording is intentionally less technical. The message is aimed at operations supervisors and production technicians, not only data engineers.

## Grafana Root URL For Email Links

Grafana uses `GF_SERVER_ROOT_URL` to build dashboard links in alert emails.

Configured through Docker Compose:

```text
docker-compose.yml: GF_SERVER_ROOT_URL=${GRAFANA_ROOT_URL:-http://localhost:3000}
```

Current local `.env` value:

```text
GRAFANA_ROOT_URL=http://136.110.54.120:3000
```

Reason:

```text
Alert emails are for operations users. They cannot open a link to the owner's Mac localhost.
Email links should point to the public/reachable VM Grafana URL.
```

If the VM external IP changes, update `GRAFANA_ROOT_URL` in the VM/local `.env` and recreate Grafana:

```bash
docker compose up -d --force-recreate grafana
```

If the project is run local-only for development, `GRAFANA_ROOT_URL=http://localhost:3000` is acceptable.

## Verified Alert Tests

Completed verification:

```text
1. SMTP credential was configured for Gmail using a Gmail App Password.
2. Direct SMTP test email was sent and received.
3. Temporary PostgreSQL rows were inserted to trigger Plant State Critical.
4. Grafana changed Plant State Critical to active/firing.
5. Gmail received the real Grafana alert email.
6. Email body was improved with operations-friendly action plan text.
7. GRAFANA_ROOT_URL was set to the VM public Grafana base URL.
8. A final alert email was sent again to verify the action plan and VM URL.
9. Temporary test rows were deleted after each test.
```

Temporary test-row pattern used during verification:

```text
grafana-email-test-*
grafana-email-template-test-*
grafana-action-plan-test-*
grafana-final-email-test-*
```

Cleanup check:

```sql
SELECT COUNT(*) AS remaining_test_rows
FROM machine_events_raw
WHERE event_id LIKE 'grafana-email-test-%'
   OR event_id LIKE 'grafana-email-template-test-%'
   OR event_id LIKE 'grafana-action-plan-test-%'
   OR event_id LIKE 'grafana-final-email-test-%';
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

Current setup:

```text
PostgreSQL alert views
→ Grafana dashboard alert feed
→ Grafana local alert rules
→ Gmail email contact point
→ Gmail alert history / audit record
→ LINE Messaging API test channel
```

Current channel roles:

```text
Gmail = official searchable alert history.
LINE = fast mobile response for critical incidents.
```

## Future Cloud Run Bridge Option

Cloud Run is not required for the current implementation.

Current cost-saving implementation:

```text
Grafana
→ LINE alert bridge container in the same Docker Compose stack
→ LINE Messaging API
→ LINE Official Account broadcast
```

Reason for the current choice:

```text
No extra Cloud Run service.
No extra Cloud Run runtime or request cost.
Fewer moving parts for the demo.
Still demonstrates Grafana webhook integration, custom alert formatting, and LINE Messaging API delivery.
```

Cloud Run remains a future professionalization option.

Future Cloud Run architecture:

```text
Grafana webhook
→ Cloud Run alert bridge
→ LINE Messaging API / future chat or incident channels
```

Why it may be useful later:

- Public webhook endpoint for services that cannot reach the private VM/container network.
- Cleaner separation between monitoring, alert formatting, and delivery.
- Central place for retry logic, deduplication, routing, and rate limiting.
- Easier audit logging for alert payloads and delivery results.
- Better pattern for multi-channel incident integrations such as LINE, Teams, Slack, PagerDuty, Jira, or ServiceNow.
- Useful portfolio upgrade because it shows serverless integration engineering on GCP.

When to consider it:

```text
Use the in-stack bridge while the project is small and cost-sensitive.
Consider Cloud Run if the project needs public webhook access, groupId capture, multiple alert targets, delivery audit logs, or a more production-style integration story.
```

## LINE Official Account Alerting

LINE alerting is now prepared and the first direct LINE Messaging API test has passed.

Dedicated reusable setup document:

```text
docs/line_official_account_alerting.md
```

Current LINE status:

| Item | Value |
| --- | --- |
| Official Account | `Kafka Alert Bot` |
| Basic ID | `@658ndqox` |
| Provider | `Kafka Monitoring Demo` |
| Channel ID | `2010459362` |
| Messaging API | Enabled |
| Current send mode | `broadcast` |
| Direct API test | Passed with HTTP 200 |
| Grafana route test | Passed with `POST /grafana` HTTP 200 |

Cost-control rule:

```text
Only CRITICAL alerts should go to LINE at first.
WARNING alerts should stay in Grafana/Gmail until the alert volume is proven stable.
Resolved LINE messages are disabled by default.
```

Reason:

```text
LINE message usage is counted by people reached. A small test audience keeps message usage low.
```

Prepared implementation:

```text
Grafana webhook contact point
→ LINE alert bridge
→ LINE Messaging API
→ LINE Official Account friends or a future group target
```

Current routing:

```text
Project alerts -> Gmail
Critical project alerts -> Gmail and LINE
```

Prepared files:

```text
alerting/line_alert_bridge.py
scripts/configure_line_alerts.sh
scripts/run_line_bridge_local.sh
scripts/test_line_alert.sh
grafana/provisioning/alerting/line_webhook_contact_point.yml
docs/line_official_account_alerting.md
```

The bridge currently supports:

- `/health` health check.
- `/grafana` endpoint for Grafana webhook payloads.
- `/line/webhook` endpoint to capture LINE webhook events and identify `groupId`, `roomId`, or `userId`.
- `broadcast` mode for sending to LINE Official Account friends without `LINE_TO_ID`.
- `push` mode for sending to one user, group, or room when `LINE_TO_ID` is known.
- Critical-only routing by default through `LINE_MIN_SEVERITY=critical`.
- Resolved-message suppression by default through `LINE_DISABLE_RESOLVED=true`.
- Dry-run behavior when required settings are missing.

Current required input for broadcast mode:

```text
LINE_CHANNEL_ACCESS_TOKEN
LINE_SEND_MODE=broadcast
```

Required input for future push/group mode:

```text
LINE_CHANNEL_ACCESS_TOKEN
LINE_SEND_MODE=push
LINE_TO_ID=<userId, groupId, or roomId>
```

Optional input for webhook signature validation:

```text
LINE_CHANNEL_SECRET
```

Use this helper to save local LINE settings:

```bash
scripts/configure_line_alerts.sh
```

Run a local direct LINE test:

```bash
scripts/test_line_alert.sh
```

Latest successful result:

```json
{
  "sent": true,
  "status": 200,
  "response": "{}"
}
```

Full Grafana route verification:

```text
Temporary critical PostgreSQL rows
→ Grafana Plant State Critical rule
→ Notification policy critical route
→ kafka-line-webhook
→ LINE bridge /grafana endpoint
→ HTTP 200
```

Temporary rows are deleted after the verification test.

Run the local bridge:

```bash
scripts/run_line_bridge_local.sh
```

Run the bridge through Docker Compose:

```bash
docker compose up -d line-alert-bridge
```

The Grafana `kafka-line-webhook` contact point is routed for critical project alerts. Gmail remains routed for all project alerts.

Future group-chat path:

```text
Enable bot group join
→ add bot to LINE group
→ expose /line/webhook publicly
→ capture groupId
→ set LINE_SEND_MODE=push and LINE_TO_ID=<groupId>
→ route Grafana CRITICAL alerts to LINE
```

Other possible future integrations:

- Microsoft Teams Workflows if a suitable Microsoft 365 work/school account is available.
- Slack webhook if the project needs a more global enterprise chat example.
- PagerDuty, Jira, ServiceNow, or another incident workflow for a more production-like incident-management layer.
- Cloud Run alert bridge if the project needs public webhook access, stronger separation, retries, routing, or audit logging.
