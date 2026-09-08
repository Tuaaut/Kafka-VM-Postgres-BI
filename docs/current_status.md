# Current Project Status

Shell convention: `powershell` examples run on Windows. `bash` examples run on the Ubuntu VM or, for optional local development, inside WSL; they are not native PowerShell commands. WSL and a local pipeline are not required for the cloud-first workflow.

This file records the current known state of the project so we can return later without guessing.

## Cloud-first Windows workflow — 2026-09-05

Decision: use Grafana during the scheduled cloud demo and exported CSV files afterward. A desktop database client and persistent PostgreSQL tunnel are outside the project workflow. Local pipeline execution is optional development only.

Progress (4/4 steps):
1. Verified Google Cloud CLI authentication and Windows SSH access.
2. Verified the Saturday 08:45–11:00 Asia/Bangkok schedule and all six VM services. A read-only SQL check returned 67,782 raw events at the test time; Grafana health was OK.
3. Removed desktop database-client setup, connection instructions, and the temporary Windows database tunnel helper from the project.
4. Stopped the manually started VM after testing; GCP reports TERMINATED. The temporary tunnel is no longer required.

Next: during the next scheduled demo, review Grafana and investigate shutdown export completion. While the VM is off, download available CSV snapshots from GCS. Live database queries and Grafana require the VM to run. CSV inspection requires no local database import.

User confirmation (2026-09-05): a LINE alert was received after the setup/test session. This confirms delivery to the user's LINE channel; the message payload and originating rule were not independently inspected in this session. It does not validate the shutdown export.

Documentation review complete: workstation references now use Windows, the old workstation-specific path and package-manager setup were removed, and shell examples explicitly distinguish Windows PowerShell from Ubuntu/optional WSL Bash. The cloud VM remains Ubuntu. No additional Markdown files were created.

Latest shutdown verification: VM status is `TERMINATED`; no setup listeners remain on the local test ports. GCS contains today's export folders `084620` and `182841`; the latter was uploaded at 18:29 Asia/Bangkok, before this session's final stop. A new export for the final stop was not found, so shutdown-export success for this stop is unconfirmed. Do not describe the latest snapshot as including all events generated during the test.

The copied Windows project folder has no `.git` metadata. Local document edits have not been committed or deployed. The previously installed desktop database application is not a project dependency; this change does not uninstall Windows applications.

See [cloud operations](gcp_vm_operations.md#windows-cloud-access-verified-2026-09-05) and [project overview](../README.md).

## Local Docker development environment — 2026-09-08

Re-established the local Docker stack on Windows as a development/testing sandbox for logic and dashboard work, kept separate from the scheduled cloud VM.

Changes:
1. Added `.env.example`. It was referenced in the README, five docs, and two scripts but missing from the folder. Values derived from `docker-compose.yml` and the producer/consumer/bridge code; no secrets.
2. Added `docker-compose.override.yml` for local-only settings: PostgreSQL host port `5433` (5432 is taken by another local project) and `line-alert-bridge` moved to a non-default `alerting` profile. `docker-compose.yml` stays identical to the VM.
3. Removed two stray DBeaver JVM crash logs (`hs_err_pid892.log`, `replay_pid892.log`) from the project root.
4. Fixed a hard-coded WSL path in `docs/local_runbook.md`.

Verified: `docker compose up -d` brings up five services (kafka, postgres, consumer, producer, grafana) and no alerting containers. End-to-end flow confirmed: producer -> Kafka -> consumer -> PostgreSQL -> control-room views. `control_room_current_status` returned `CRITICAL` from the seed data (about 50% failure rate in the opening window), which settles toward `NORMAL` as steady-state events accumulate. The whole stack used about 440 MiB RAM. Grafana health reported `database: ok`.

Alerting is intentionally inert locally: `GRAFANA_SMTP_ENABLED=false` and the LINE bridge is not started. Alert rules still evaluate so state is visible in the Grafana UI, but nothing is delivered. The cloud VM remains the only environment that sends Gmail/LINE alerts.

There is no local schedule: the stack is started and stopped on demand. The Saturday 08:45-11:00 Asia/Bangkok window is a GCP instance schedule for VM cost control only.

Workstation Docker memory (WSL 2, `~/.wslconfig`) was raised from 6 GB to 8 GB to allow one or two development stacks at once; physical RAM is about 15.7 GB, so other Windows apps still need to be kept trimmed.

This folder is now initialized as a local Git repository with a first commit. There is no remote; nothing has been pushed.

## Summary

The Kafka to PostgreSQL pipeline is deployed on a Singapore GCP VM and runs during scheduled demo windows. At the end of the 2026-09-05 Windows setup session, the VM was stopped. The local-service details and older test results below are historical reference, not required Windows setup.

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
Alert email/dashboard root URL: http://136.110.54.120:3000
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
Gmail email contact point: kafka-gmail-email
Gmail recipient: pattaratua@gmail.com
Alert email root URL: http://136.110.54.120:3000
LINE Official Account: Kafka Alert Bot
LINE test mode: broadcast
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
Reserved public IP: 136.110.54.120
Access model: SSH tunnel first
```

Confirmed:

```text
Docker Compose stack is running on the VM.
Grafana dashboard opens from the Windows workstation through http://localhost:3001.
Public Grafana dashboard URL is documented as http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room.
Alert email dashboard links use root URL http://136.110.54.120:3000.
Rows are increasing in PostgreSQL.
control_room_current_status returns live values.
The old US Central VM was deleted after Singapore was verified.
```

Confirmed VM scheduling:

```text
Resource policy: kafka-demo-uat-hours
Timezone: Asia/Bangkok
Frequency: Every Saturday
Start: Saturday 08:45
Stop: Saturday 11:00
Purpose: UAT/demo runtime without 24/7 compute cost
Startup script: scripts/gcp_vm_startup.sh
Startup log: /var/log/kafka-monitoring-startup.log
Shutdown/export service: kafka-monitoring-gcs-export.service
Export script: scripts/export_vm_postgres_to_gcs.sh
Verified startup containers: Kafka, PostgreSQL, Grafana, producer, consumer, LINE bridge
```

Confirmed GCS export plan:

```text
No local PostgreSQL CLI installation is required for the Windows workflow.
Local Docker PostgreSQL remains the optional manual import target on localhost:5432.
The VM exports PostgreSQL snapshots to Cloud Storage before shutdown.
GCS bucket: gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp
Export path: kafka-postgres-bi/exports/YYYY-MM-DD/HHMMSS/
Export files: machine_events_raw, control-room views, realtime summary, and manifest.
Cloud Storage lifecycle deletes export objects after 5 days.
The Windows workstation does not need to be online during the VM export.
Manual local import can happen later when the Windows workstation is online.
Verified manual export path: gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp/kafka-postgres-bi/exports/2026-06-21/041342/
Verified systemd shutdown-export path created additional GCS export folders.
Verified real VM stop export path: gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp/kafka-postgres-bi/exports/2026-06-21/042501/
```

See `docs/gcp_vm_operations.md` for the Grafana access, SQL diagnostics, monitoring, stop/start, and upgrade commands.

## Confirmed Gmail Alerting Result

Grafana email alerting is now configured and verified locally.

Completed:

```text
Alert rules are provisioned as code.
Gmail contact point is provisioned as code.
Notification policy routes project alerts to the Gmail contact point.
Gmail SMTP is enabled in local .env.
Gmail sender: pattaratua@gmail.com.
Gmail recipient: pattaratua@gmail.com.
SMTP test email was received.
Real Grafana alert email was received from the Plant State Critical rule.
Alert email body was customized for operations users with summary, impact, action plan, dashboard link, and resolution note.
Grafana root URL is explicitly configured so alert links use the VM public Grafana base URL instead of localhost.
```

Current local secret handling:

```text
Gmail SMTP values are stored in local .env only.
.env is ignored by Git.
The Gmail App Password must not be committed or written into Markdown docs.
```

Latest verified email behavior:

```text
1. A direct SMTP test email was sent and received with subject:
   Kafka Monitoring Grafana SMTP test
2. A real Grafana alert was triggered by temporary test rows.
3. Gmail received the Plant State Critical alert.
4. The alert email showed an operations-friendly action plan instead of raw A/B/C evaluator output.
5. Test rows were deleted after each verification.
6. The database returned to NO_DATA/NORMAL after cleanup depending on whether live producer data existed in the 15-minute window.
```

Current `Plant State Critical` action plan:

```text
1. Open the Grafana control-room dashboard and confirm the Plant State panel.
2. Check the latest alert feed to identify the affected production line, machine, and reason.
3. Notify the responsible technician or production support owner to inspect the line and take action as soon as possible.
4. Keep the incident open until the dashboard returns to NORMAL or the root cause is confirmed.
```

Useful configuration files:

```text
grafana/provisioning/alerting/kafka_alert_rules.yml
grafana/provisioning/alerting/gmail_contact_point.yml
docker-compose.yml
.env.example
```

If SMTP needs to be reconfigured later, use `scripts/configure_gmail_alerts.sh`. Use a Gmail App Password, not the normal Gmail password.

## Confirmed LINE Alerting Result

LINE alerting is prepared as the fast mobile response channel.

Completed:

```text
LINE Official Account was created.
Messaging API was enabled.
LINE channel access token was generated and saved only in local .env.
LINE bridge was added for Grafana webhook payloads.
Broadcast mode was added so first testing does not require LINE_TO_ID.
Real LINE Messaging API test returned HTTP 200.
Full Grafana-to-LINE route test returned HTTP 200 from the LINE bridge.
```

Current LINE resources:

```text
Official Account name: Kafka Alert Bot
Basic ID: @658ndqox
Provider: Kafka Monitoring Demo
Channel ID: 2010459362
Current send mode: broadcast
Current target: LINE Official Account friends/followers
Grafana route status: critical project alerts routed to LINE
```

Current local secret handling:

```text
LINE_CHANNEL_ACCESS_TOKEN is stored in local .env only.
.env is ignored by Git.
LINE tokens and secrets must not be written into Markdown docs.
```

Useful files:

```text
docs/line_official_account_alerting.md
alerting/line_alert_bridge.py
scripts/configure_line_alerts.sh
scripts/run_line_bridge_local.sh
scripts/test_line_alert.sh
grafana/provisioning/alerting/line_webhook_contact_point.yml
```

Current limitation:

```text
True LINE group-chat push is not enabled yet because groupId has not been captured.
```

Next LINE step:

```text
For the current MVP, run the LINE bridge with Docker Compose and use broadcast mode.
For future group-chat push, capture groupId and switch LINE_SEND_MODE=push.
```

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

Check VM resources:

```bash
gcloud compute ssh kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a --command 'free -h; df -h /; cd ~/Kafka-VM-Postgres-BI && sudo docker compose ps; sudo docker stats --no-stream'
```

## Important Decisions

- Use PostgreSQL as a Docker container, not a native Windows workstation install.
- Use `scripts/query_postgres.sh` for fast terminal SQL.
- Use Grafana for the real-time dashboard.
- Keep Grafana dashboard definitions as code under `grafana/dashboards/`.
- Keep Grafana provisioning under `grafana/provisioning/`.
- Use one Kafka topic first: `machine_events`.
- Keep producer default at 10 events every 60 seconds.
- Start locally first, then run the same stack on the GCP VM.
- Use Singapore `e2-small` as the current low-cost demo VM.
- Upgrade to `e2-medium` only if Grafana, Kafka, PostgreSQL, or alerting becomes unstable.
- Use Compute Engine instance schedule for UAT/demo windows instead of 24/7 runtime.
- Gmail SMTP is configured locally and verified. Keep SMTP secrets only in `.env` or a VM-only secret pattern.
- Alert email dashboard links should use `GRAFANA_ROOT_URL=http://136.110.54.120:3000` for the operations-team/public VM dashboard experience.

## Known Notes

- A simple Kafka smoke-test JSON message can be consumed by Kafka but skipped by the PostgreSQL consumer if it does not match the machine event contract.
- This is expected behavior.
- PostgreSQL data persists in the Docker named volume unless `docker compose down -v` is used.
- If SQL files change after PostgreSQL has already initialized, either apply SQL manually or recreate the volume.

## Next Step

Continue validating the Singapore VM dashboard and resource usage. The next optional build step is LINE group-chat alerting for immediate response, while Gmail remains the official searchable alert record.

LINE alerting progress:

```text
LINE alert bridge is prepared.
Local formatting test passed.
Real LINE Messaging API broadcast test passed.
Docker Compose starts the LINE bridge as part of the default stack.
Grafana LINE webhook contact point is routed for critical project alerts.
Full Grafana-to-LINE route test passed with POST /grafana HTTP 200.
True group-chat push is waiting for groupId capture and LINE_SEND_MODE=push.
```

LINE cost-control decision:

```text
Send only CRITICAL alerts to LINE at first.
Keep WARNING alerts in Grafana/Gmail.
Disable resolved LINE messages by default.
Use a small test group to keep message usage low.
```

Useful local dashboard sources:

```text
control_room_current_status
control_room_machine_status
control_room_alert_feed
machine_status_minute
dashboard_realtime_summary
```
