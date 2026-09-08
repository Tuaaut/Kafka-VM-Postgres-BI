#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID first}"
: "${GCP_ZONE:=asia-southeast1-a}"
: "${GCP_VM_NAME:=kafka-postgres-bi-sg}"
: "${GCP_MACHINE_TYPE:=e2-small}"

gcloud compute instances create "$GCP_VM_NAME" \
  --project "$GCP_PROJECT_ID" \
  --zone "$GCP_ZONE" \
  --machine-type "$GCP_MACHINE_TYPE" \
  --image-family ubuntu-2404-lts-amd64 \
  --image-project ubuntu-os-cloud \
  --boot-disk-size 30GB \
  --boot-disk-type pd-standard \
  --tags kafka-postgres-bi \
  --metadata enable-oslogin=TRUE
