#!/usr/bin/env bash
set -euo pipefail

docker exec kafka_vm_kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --if-not-exists \
  --topic machine_events \
  --partitions 1 \
  --replication-factor 1

docker exec kafka_vm_kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
