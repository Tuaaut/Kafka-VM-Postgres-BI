# GCP VM Operations Runbook

Shell convention: `powershell` examples run on Windows. `bash` examples run on the Ubuntu VM or, for optional local development, inside WSL; they are not native PowerShell commands. WSL and a local pipeline are not required for the cloud-first workflow.

This runbook records the current Singapore VM setup, Grafana access, SQL diagnostics, and resource monitoring process.

Use this when returning to the cloud demo after local development.

## Windows cloud access (verified 2026-09-05)

Windows holds project files and provides browser/CLI access. The pipeline and PostgreSQL run on the scheduled GCP VM. No desktop database client, local PostgreSQL, or persistent database tunnel is required.

1. During the Saturday 08:45–11:00 Asia/Bangkok window, open the [Grafana dashboard](http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room).
2. Outside that window, leave the VM stopped. Review exports in [Cloud Storage](https://console.cloud.google.com/storage/browser/kafka-postgres-bi-exports-retail-bigquery-project-webapp/kafka-postgres-bi/exports?project=retail-bigquery-project-webapp). Download/decompress CSV snapshots when needed; they are not a live database. The lifecycle configuration retains exports for five days.
3. For troubleshooting while the VM is already running, use the SSH button in [VM Instances](https://console.cloud.google.com/compute/instances?project=retail-bigquery-project-webapp), then run SQL inside its PostgreSQL container as described below.
4. If manually starting the VM outside the demo window, stop it as soon as the check finishes. Manual start does not create a short automatic timeout.

Google Cloud CLI is already authenticated on Windows. These commands work in PowerShell:

- Inspect: `gcloud compute instances describe kafka-postgres-bi-sg --project retail-bigquery-project-webapp --zone asia-southeast1-a --format="value(status)"`
- Start only when needed: `gcloud compute instances start kafka-postgres-bi-sg --project retail-bigquery-project-webapp --zone asia-southeast1-a`
- Stop after use: `gcloud compute instances stop kafka-postgres-bi-sg --project retail-bigquery-project-webapp --zone asia-southeast1-a`

The optional Grafana tunnel below is a PowerShell command for private debugging, not required Windows setup. Keep that terminal open while using the tunnel and press `Ctrl+C` afterward. The Windows project folder has no `.git` metadata; edits do not deploy automatically. See [progress](current_status.md#cloud-first-windows-workflow--2026-09-05).

## Current VM

```text
GCP project: YOUR_GCP_PROJECT_ID
Region: asia-southeast1
Zone: asia-southeast1-a
VM name: kafka-postgres-bi-sg
Machine type: e2-small
Disk: 30 GB standard persistent disk
OS: Ubuntu 24.04 LTS
External IP: EXTERNAL_IP_WHEN_RUNNING
Reserved public IP: 136.110.54.120 (`kafka-grafana-public-ip`)
Access model: SSH tunnel first
Public Grafana base URL for alert emails: http://136.110.54.120:3000
```

The old US Central test VM was deleted after the Singapore VM was verified.

## What Runs On The VM

```text
GCP Compute Engine VM
└── Docker Compose
    ├── Kafka container
    ├── PostgreSQL container
    ├── Grafana container
    ├── Producer container
    ├── Consumer container
    └── LINE alert bridge container
```

Grafana does not read JSON files directly. The current serving path is:

```text
Producer
→ Kafka
→ Consumer
→ PostgreSQL
→ Grafana
```

PostgreSQL stays in the architecture because it gives Grafana a stable SQL source and gives us a second way to validate dashboard numbers through terminal SQL inside the VM.

## Why The Browser Uses Localhost

When the dashboard is opened at `http://localhost:3001`, it is still showing the Grafana server on the VM.

The path is:

```text
Windows workstation browser
→ localhost:3001
→ SSH tunnel
→ VM localhost:3000
→ Grafana container
```

This is intentional for private testing. It avoids opening Grafana publicly on the internet while we are testing.

For operations-team alert emails, do not use a Windows workstation `localhost` link. Alert emails should use the public/reachable VM Grafana base URL:

```text
http://136.110.54.120:3000
```

This value is controlled by `GRAFANA_ROOT_URL` and passed into Grafana as `GF_SERVER_ROOT_URL`.

## Open Grafana Through SSH Tunnel

Optional Windows PowerShell tunnel (uses the SSH key initialized during setup):

```powershell
ssh -i "$env:USERPROFILE/.ssh/google_compute_engine" -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 127.0.0.1:3001:localhost:3000 pattaratua_gmail_com@136.110.54.120
```

Then open:

```text
http://localhost:3001
```

Login:

```text
User: admin
Password: admin
Dashboard: Kafka Monitoring / Kafka Machine Monitoring Control Room
```

For a shared public demo, change the Grafana admin password first, then add a restricted firewall rule for trusted source IPs only. Do not expose PostgreSQL publicly.

Public dashboard currently documented for demo sharing:

```text
http://136.110.54.120:3000/d/kafka-machine-monitoring/kafka-machine-monitoring-control-room
```

The current public IP is reserved as `kafka-grafana-public-ip`, so scheduled stop/start should keep the same Grafana alert-link base URL.

If the VM external IP ever changes, update `GRAFANA_ROOT_URL` and recreate Grafana so future email links stay correct:

```bash
perl -0pi -e 's#^GRAFANA_ROOT_URL=.*#GRAFANA_ROOT_URL=http://NEW_VM_EXTERNAL_IP:3000#m' .env
docker compose up -d --force-recreate grafana
```

## SQL Validation Queries

While the VM is running, open browser SSH from GCP Console and run `sudo docker exec -it kafka_vm_postgres psql -U monitoring_user -d machine_monitoring`. Use these read-only queries to cross-check Grafana, then exit with `\q`:

```sql
SELECT * FROM control_room_current_status;

SELECT *
FROM control_room_machine_status
ORDER BY line_id, machine_id;

SELECT *
FROM control_room_alert_feed
ORDER BY event_time DESC
LIMIT 100;

SELECT
    COUNT(*) AS rows_total,
    MAX(event_time) AS latest_event_time
FROM machine_events_raw;
```

## VM Resource Monitoring

Use this when checking whether `e2-small` is still enough:

```bash
gcloud compute ssh kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a \
  --command 'free -h; df -h /; cd ~/Kafka-VM-Postgres-BI && sudo docker compose ps; sudo docker stats --no-stream'
```

Individual checks:

```bash
free -h
df -h /
cd ~/Kafka-VM-Postgres-BI && sudo docker compose ps
sudo docker stats --no-stream
```

GCP Console path:

```text
Compute Engine
→ VM instances
→ kafka-postgres-bi-sg
→ Observability
```

The basic GCP VM page shows CPU, disk, and network. Detailed memory charts usually require the Ops Agent, so terminal checks are enough for the current demo.

## Capacity Rules

Keep `e2-small` if:

- Grafana remains responsive.
- Kafka, PostgreSQL, producer, and consumer stay running.
- Available memory usually stays above about 300 MB.
- Swap stays low and does not keep growing.
- CPU is not constantly above about 70%.
- Disk remains below about 80% full.
- Ingest lag usually stays below the alert threshold.

Upgrade to `e2-medium` if:

- Grafana becomes slow during normal demo use.
- Containers restart because of memory pressure.
- Swap usage grows steadily.
- Kafka or PostgreSQL becomes unstable.
- Dashboard refreshes or alert rules become unreliable.

## Upgrade VM Size

Stop the VM, change the machine type, then start it again:

```bash
gcloud compute instances stop kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a

gcloud compute instances set-machine-type kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a \
  --machine-type e2-medium

gcloud compute instances start kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a
```

This keeps the disk and project files. The external ephemeral IP can change after stop/start, but SSH tunnels through `gcloud compute ssh` still work by VM name.

## Stop And Start For Cost Control

## Scheduled UAT Runtime

The VM uses a Compute Engine instance schedule so it does not need to run 24/7.

Current schedule:

```text
Resource policy: kafka-demo-uat-hours
Region: asia-southeast1
Timezone: Asia/Bangkok
Frequency: Every Saturday
Start: Saturday 08:45
Stop: Saturday 11:00
Purpose: UAT/demo window around 09:00 while limiting compute cost
```

GCP schedule commands:

```bash
gcloud compute resource-policies describe kafka-demo-uat-hours \
  --project retail-bigquery-project-webapp \
  --region asia-southeast1

gcloud compute instances describe kafka-postgres-bi-sg \
  --project retail-bigquery-project-webapp \
  --zone asia-southeast1-a \
  --format='value(status,resourcePolicies)'
```

Startup behavior:

```text
Compute Engine starts the VM every Saturday at 08:45 Asia/Bangkok.
The VM startup script runs automatically.
The startup script starts the Docker Compose stack.
The startup script installs/enables the pre-shutdown GCS export service.
Producer emits 10 events every 60 seconds.
Grafana reads PostgreSQL and evaluates alert rules.
Critical alerts route to Gmail and LINE.
Before shutdown, the VM exports PostgreSQL snapshots to GCS.
Compute Engine stops the VM every Saturday at 11:00 Asia/Bangkok.
```

Startup script:

```text
scripts/gcp_vm_startup.sh
scripts/install_vm_shutdown_export_service.sh
scripts/export_vm_postgres_to_gcs.sh
```

The same script is stored in VM metadata as `startup-script`. It writes logs to:

```text
/var/log/kafka-monitoring-startup.log
```

Manual startup-script test:

```bash
gcloud compute ssh kafka-postgres-bi-sg \
  --project retail-bigquery-project-webapp \
  --zone asia-southeast1-a \
  --command 'curl -fsS -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/startup-script | sudo bash'
```

Current verified startup result:

```text
kafka_vm_kafka: running
kafka_vm_postgres: running
kafka_vm_grafana: running and healthy
kafka_vm_producer: running
kafka_vm_consumer: running
kafka_vm_line_alert_bridge: running and healthy
Grafana notification policy: Gmail for project alerts, LINE for critical project alerts
Latest PostgreSQL event time updated after startup
```

Important deployment note:

```text
The VM project folder is not currently a Git checkout.
For future code changes, deploy the updated project files to the VM before relying on the startup script.
Do not overwrite the VM .env unless intentionally updating secrets.
```

## Weekly GCS PostgreSQL Export

Verification note (2026-09-05): exports exist, but the latest observed upload was at 18:29 Asia/Bangkok, before the final manual stop in this session. A fresh export for that final stop was not found. During the next scheduled window, inspect `kafka-monitoring-gcs-export.service` logs and verify upload timestamps after shutdown. Do not assume every stop has produced a complete fresh snapshot.

When the VM is stopped, live PostgreSQL queries and Grafana are unavailable. To keep a reviewable copy without depending on the Windows workstation, the VM exports PostgreSQL snapshots to Cloud Storage before the scheduled weekly shutdown or a manual shutdown.

Current bucket:

```text
gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp
```

Export path:

```text
kafka-postgres-bi/exports/YYYY-MM-DD/HHMMSS/
```

Current exported files:

```text
machine_events_raw.csv.gz
control_room_current_status.csv.gz
control_room_machine_status.csv.gz
control_room_alert_feed.csv.gz
dashboard_realtime_summary.csv.gz
manifest.json
```

Retention:

```text
Cloud Storage lifecycle deletes export objects after 5 days.
```

Verified export:

```text
gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp/kafka-postgres-bi/exports/2026-06-21/041342/
Real VM shutdown export verified: gs://kafka-postgres-bi-exports-retail-bigquery-project-webapp/kafka-postgres-bi/exports/2026-06-21/042501/
```

Windows workstation dependency:

```text
VM schedule does not need the Windows workstation.
GCS export does not need the Windows workstation.
Downloaded CSV snapshots can be inspected on Windows without a local PostgreSQL server.
```

## Manual Stop And Start

Stop when not testing:

```bash
gcloud compute instances stop kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a
```

Start when testing:

```bash
gcloud compute instances start kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a
```

When the VM is stopped, compute cost stops. Disk cost remains.

## Current Known Good Result

The Singapore `e2-small` VM has been verified with:

```text
Grafana dashboard reachable through localhost:3001
Producer and consumer running on the VM
PostgreSQL rows increasing
control_room_current_status returning live values
```

At the last capacity check, `e2-small` looked acceptable for the demo:

```text
RAM: about 949 MiB available
Swap: about 8 MiB used out of 2 GiB
Disk: about 22 GB free out of 29 GB
Largest container: Kafka, about 364 MiB
```

Continue monitoring during demos. If pressure appears, upgrade to `e2-medium`.
