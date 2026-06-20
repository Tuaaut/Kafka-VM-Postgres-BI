# GCP VM Setup

This project starts locally first, then moves the same Docker Compose stack to a small Google Cloud Compute Engine VM.

## Why GCP For This Project

The workload is small and experimental:

```text
Kafka
→ Python consumer
→ PostgreSQL
→ Grafana
```

A small Compute Engine VM is easier to control than multiple managed services. The VM can be stopped when not testing, and the user already has a GCP project with budget alerts.

## Current VM Path

Current verified demo VM:

```text
Project: YOUR_GCP_PROJECT_ID
Region: asia-southeast1
Zone: asia-southeast1-a
VM name: kafka-postgres-bi-sg
Machine type: e2-small
vCPU / RAM: 2 shared vCPU, 2 GB RAM
Disk: 30 GB standard persistent disk
OS: Ubuntu 24.04 LTS
Firewall: allow SSH only first
```

Upgrade path if needed:

```text
Machine type: e2-medium
vCPU / RAM: 2 shared vCPU, 4 GB RAM
Use only if e2-small becomes slow or memory-constrained.
```

Current recommendation:

```text
Keep e2-small for the demo while Grafana, Kafka, PostgreSQL, producer, and consumer remain stable.
Upgrade to e2-medium only when resource monitoring shows pressure.
```

Avoid for the full stack:

```text
e2-micro
```

Reason:

```text
Kafka, PostgreSQL, Python producer, and Python consumer together can exceed the comfortable memory range.
```

## Architecture On The VM

```text
GCP Compute Engine VM
├── Docker Compose
│   ├── Kafka container: apache/kafka:3.7.0
│   ├── PostgreSQL container: postgres:16
│   ├── Grafana container: grafana/grafana-oss
│   ├── Producer container
│   └── Consumer container
└── Users open Grafana in a browser
```

Kafka runs in KRaft mode. Zookeeper is not used.

## Low-Cost Data Rate

Use a small burst every 60 seconds:

```text
10 events every 60 seconds
```

That creates:

```text
600 events/hour
14,400 events/day
100,800 events/week
```

Configured defaults:

```bash
PRODUCER_EVENT_INTERVAL_SECONDS=60
PRODUCER_EVENTS_PER_BATCH=10
```

## Create VM Example

Review and edit the helper before running:

```bash
scripts/gcp_create_vm_example.sh
```

Expected shape:

```bash
gcloud compute instances create kafka-postgres-bi-sg \
  --project=YOUR_GCP_PROJECT_ID \
  --zone=asia-southeast1-a \
  --machine-type=e2-small \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB
```

Use the GCP Console if that is faster. The important part is the VM size, OS, disk, and firewall control.

## VM Bootstrap Commands

Run on the Ubuntu VM:

```bash
sudo apt-get update
sudo apt-get install -y git python3 python3-venv python3-pip ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

Log out and back in after adding the Docker group.

## Project Setup On VM

Clone or copy the project folder, then:

```bash
cd Kafka-VM-Postgres-BI
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
scripts/start_services.sh
scripts/create_topics.sh
```

The producer and consumer start through Docker Compose.

Verify:

```bash
scripts/verify_postgres_counts.sh
scripts/query_postgres.sh "SELECT * FROM control_room_current_status;"
```

## Grafana Connectivity

Local Mac development uses:

```text
http://localhost:3000
```

On a GCP VM, Grafana runs on the VM and connects to PostgreSQL inside Docker:

```text
Grafana container
→ postgres:5432
→ PostgreSQL container
```

Users should access Grafana, not PostgreSQL directly.

Safer first option for testing Grafana from the Mac:

```bash
gcloud compute ssh kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a \
  -- -N -L 3001:localhost:3000
```

Then open on the Mac:

```text
http://localhost:3001
```

because the SSH tunnel forwards local port 3001 to Grafana on the VM.

For operations-team alert emails, set the Grafana root URL to the public/reachable VM Grafana base URL, not the Mac tunnel URL:

```text
GRAFANA_ROOT_URL=http://136.110.54.120:3000
```

This controls the dashboard links inside Gmail alert emails. If the external IP changes, update `GRAFANA_ROOT_URL` in `.env` and recreate Grafana.

For sharing with other users, use a restricted firewall rule for port `3000` only after changing the default Grafana admin password.

Avoid opening PostgreSQL port `5432` to the internet.

For DBeaver, use a PostgreSQL tunnel:

```bash
gcloud compute ssh kafka-postgres-bi-sg \
  --project YOUR_GCP_PROJECT_ID \
  --zone asia-southeast1-a \
  -- -N -L 5433:localhost:5432
```

Then connect DBeaver to:

```text
Host: localhost
Port: 5433
Database: machine_monitoring
User: monitoring_user
Password: monitoring_password
```

Detailed tunnel, DBeaver, monitoring, stop/start, and upgrade commands are in `docs/gcp_vm_operations.md`.

## Operations

Stop containers but keep data:

```bash
docker compose stop
```

Stop containers:

```bash
docker compose down
```

Reset data:

```bash
scripts/reset_postgres_data.sh
```

Stop VM when not testing:

```bash
gcloud compute instances stop kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a
```

Start VM:

```bash
gcloud compute instances start kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a
```

## Cost Controls

- Keep the VM stopped when not testing.
- Use `e2-small` while it remains stable.
- Upgrade to `e2-medium` only if monitoring shows pressure.
- Review `docs/gcp_cost_plan.md` and `docs/gcp_vm_operations.md` before changing VM size or access.
- Keep event generation at 10 events every 60 seconds unless testing load.
- Keep PostgreSQL on the same VM for the demo phase.
- Prefer SSH tunnel for early Grafana testing.
- If sharing Grafana, open port 3000 only to trusted source IPs.
- Do not open PostgreSQL port 5432 unless there is a specific reason.
- Keep the GCP budget alert enabled.

## GCP Migration Checklist

- Local pipeline works.
- Grafana dashboard works locally.
- Singapore VM created.
- Docker installed.
- Project copied to VM.
- `.env` created.
- `docker compose up -d` works.
- Kafka topic exists.
- Consumer runs.
- Producer runs.
- PostgreSQL receives rows.
- SSH tunnel or restricted Grafana firewall access tested.
- Grafana dashboard opens from the Mac.
- PostgreSQL opens from DBeaver through SSH tunnel.
- VM resource usage checked.
- Screenshots captured for portfolio.
