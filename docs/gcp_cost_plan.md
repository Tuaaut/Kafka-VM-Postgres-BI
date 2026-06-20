# GCP Cost Plan

This file records the cost-first plan for running the Kafka, PostgreSQL, and Grafana stack on a Google Cloud Compute Engine VM.

## Current Cloud State

Current status:

```text
Local Docker Compose stack works.
Singapore GCP VM is running the same stack.
Current VM: kafka-postgres-bi-sg, asia-southeast1-a, e2-small.
Grafana can be reached through localhost:3001 SSH tunnel for private testing.
Alert email dashboard links use public VM base URL http://136.110.54.120:3000.
PostgreSQL is reached through localhost:5433 SSH tunnel for DBeaver.
Gmail SMTP is configured and verified locally.
Compute Engine instance schedule starts/stops the VM for UAT.
```

Decision:

```text
Keep e2-small for now because it has been verified and looks cheaper.
Upgrade to e2-medium only if monitoring shows pressure.
```

## Local Resource Sample

Sample from the local running containers:

| Container | CPU | RAM |
| --- | ---: | ---: |
| Grafana | 1.11% | 96.8 MiB |
| Producer | 0.01% | 14.26 MiB |
| Consumer | 0.10% | 25.39 MiB |
| Kafka | 1.43% | 446.7 MiB |
| PostgreSQL | 0.00% | 22.96 MiB |

Observed container RAM total:

```text
About 606 MiB, excluding Ubuntu OS, Docker overhead, page cache, and runtime spikes.
```

Current interpretation:

```text
e2-small has been tested on the Singapore VM and is acceptable for the current demo.
Keep monitoring memory, swap, CPU, disk, and Grafana responsiveness.
```

## Recommended VM Choice

Current choice:

```text
Machine type: e2-small
vCPU / RAM: 2 shared vCPU, 2 GB RAM
Boot disk: 30 GB standard persistent disk or balanced persistent disk
OS: Ubuntu 24.04 LTS
Access: SSH tunnel first for private testing; public Grafana only when intentionally sharing the demo
```

Why:

- It is cheaper than e2-medium.
- It has enough room for the current low-volume producer rate.
- Swap is enabled as a safety buffer.
- The dashboard and DBeaver tunnel have already been verified.
- The VM can be upgraded quickly if it becomes too tight.

Upgrade path:

```text
If e2-small becomes unstable, stop the VM and change machine type to e2-medium.
```

Avoid:

```text
e2-micro
```

Reason:

```text
1 GB RAM is too tight for Kafka + PostgreSQL + Grafana + producer + consumer.
```

## Monthly Cost Estimate

These are planning estimates. Verify final numbers in the GCP Pricing Calculator before leaving the VM running for long periods.

Assumption:

```text
Region: asia-southeast1
Runtime: 730 hours/month if left on 24/7
OS: Ubuntu/Linux
Disk: 30 GB
```

| Item | Estimated monthly cost if always on | Note |
| --- | ---: | --- |
| `e2-small` compute | lower than e2-medium | Current verified demo size. |
| `e2-medium` compute | roughly about 2x e2-small | Upgrade only if needed. |
| 30 GB standard persistent disk | small monthly cost | Disk remains billed when VM is stopped. |
| Reserved external IPv4 | a few dollars/month depending on GCP pricing | Current public Grafana IP is reserved as `kafka-grafana-public-ip`. |
| Network egress | likely near zero for demo | Grafana traffic is small. |

Practical always-on expectation:

```text
e2-small should remain the lower-cost option.
Singapore pricing can differ from US examples, so recheck the GCP calculator before leaving it always-on.
```

Practical testing-only expectation:

```text
If the VM runs only 40 hours/month:
compute is roughly 40 / 730 of the monthly compute cost.
Disk still remains billed while the VM is stopped.
```

## Cost Controls

Use these rules:

- Use the Compute Engine instance schedule instead of leaving the VM on 24/7.
- Keep the VM stopped when outside the UAT/demo window.
- Keep the disk small at first: 20-30 GB.
- Use standard persistent disk first unless boot performance feels poor.
- Keep the reserved static external IP because alert emails and public dashboard links depend on stable `http://136.110.54.120:3000`.
- Use SSH tunnel for Grafana first:

```bash
gcloud compute ssh kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a -- -N -L 3001:localhost:3000
```

- Do not open PostgreSQL port `5432`.
- Open Grafana port `3000` only when sharing the demo, and only with the intended firewall/public-access posture.
- Keep `GRAFANA_ROOT_URL` aligned with the URL users should open from alert emails.
- Keep producer at:

```text
10 events every 60 seconds
```

- Keep GCP budget alert enabled.
- Use the current scheduled runtime:

```text
Start: 08:45 Asia/Bangkok
Stop: 11:00 Asia/Bangkok
Resource policy: kafka-demo-uat-hours
```

- Keep a manual shutdown habit after any extra test session:

```bash
gcloud compute instances stop VM_NAME --zone ZONE
```

Current VM stop command:

```bash
gcloud compute instances stop kafka-postgres-bi-sg --project YOUR_GCP_PROJECT_ID --zone asia-southeast1-a
```

## Production-Like Demo Plan

Phase 1:

```text
Create e2-small Singapore VM
Deploy Docker Compose stack
Use SSH tunnel to open Grafana
Verify pipeline and dashboard
```

Phase 2:

```text
Gmail SMTP local setup verified
Real Grafana alert email verified
Move SMTP values to secure VM-only .env or secret pattern before relying on VM-side alerting long term
Keep PostgreSQL private
```

Phase 3:

```text
Monitor e2-small stability
Upgrade to e2-medium only if dashboard, Kafka, PostgreSQL, or alerting becomes unreliable
```

Phase 4:

```text
Use Compute Engine instance schedule for UAT/demo windows
Startup script runs Docker Compose automatically after VM start
Avoid Cloud Run and GitHub Actions for VM orchestration unless future requirements change
```

Phase 5:

```text
Use GCS PostgreSQL export for offline review after VM shutdown
GCS export does not require the Mac to be online during the VM runtime window
Keep export retention short with a 5-day Cloud Storage lifecycle rule
Manual local PostgreSQL import can happen later when needed
```

See `docs/gcp_vm_operations.md` for live resource checks and upgrade commands.

## Sources To Recheck

- Google Compute Engine pricing page: https://cloud.google.com/products/compute/pricing
- Google E2 machine family docs: https://cloud.google.com/compute/docs/general-purpose-machines
- Google Persistent Disk pricing: https://cloud.google.com/compute/disks-image-pricing
- Google Cloud Storage pricing: https://cloud.google.com/storage/pricing
- Google VPC external IP pricing: https://cloud.google.com/vpc/network-pricing
- GCP Pricing Calculator: https://cloud.google.com/products/calculator
