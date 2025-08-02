#!/bin/bash
set -euo pipefail
set -x

for T in connect-configs connect-offsets connect-status; do
  /opt/bitnami/kafka/bin/kafka-topics.sh \
    --bootstrap-server "kafka:9092" \
    --create --if-not-exists \
    --topic "$T" \
    --partitions 1 \
    --replication-factor 1 \
    --config cleanup.policy=compact
done
