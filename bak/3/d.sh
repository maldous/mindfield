#!/usr/bin/env bash
set -euo pipefail

OUT="debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

echo "[*] Collecting cluster events"
microk8s kubectl get events -A --sort-by='.metadata.creationTimestamp' >"$OUT/events.txt"

echo "[*] Listing all pods"
microk8s kubectl get pods -A -o wide >"$OUT/pods.txt"

# List of critical pods to inspect
PODS=(
  "auth/keycloak-0"
  "data/opensearch-cluster-master-0"
  "data/redisinsight-0"
  "messaging/akhq-5d5dd6bbdc-ddcvh"
)

for full in "${PODS[@]}"; do
  IFS="/" read -r ns pod <<<"$full"
  echo "[*] Describing $full"
  microk8s kubectl describe pod -n "$ns" "$pod" >"$OUT/${ns}_${pod}_describe.txt" 2>&1 || true

  # Capture container logs
  containers=$(microk8s kubectl get pod -n "$ns" "$pod" -o jsonpath='{.spec.containers[*].name}')
  for c in $containers; do
    echo "[*] Logs: $full container $c"
    microk8s kubectl logs -n "$ns" "$pod" -c "$c" --tail=200 >"$OUT/${ns}_${pod}_${c}.log" 2>&1 || true
  done

  # Capture initContainer logs
  inits=$(microk8s kubectl get pod -n "$ns" "$pod" -o jsonpath='{.spec.initContainers[*].name}')
  for ic in $inits; do
    echo "[*] Logs: $full initContainer $ic"
    microk8s kubectl logs -n "$ns" "$pod" -c "$ic" --tail=200 >"$OUT/${ns}_${pod}_init_${ic}.log" 2>&1 || true
  done
done

echo "[*] Capturing Temporal schema job logs"
microk8s kubectl logs -n temporal job/temporal-schema-1 --tail=200 >"$OUT/temporal_schema_job.log" 2>&1 || true

echo "[*] Capturing Helm chart values"
declare -A RELEASES=(
  ["auth/keycloak"]="bitnami/keycloak"
  ["data/opensearch"]="opensearch/opensearch"
  ["data/redisinsight"]="redisinsight/redisinsight"
  ["messaging/akhq"]="akhq/akhq"
  ["temporal/temporal"]="temporal/temporal"
)
for full in "${!RELEASES[@]}"; do
  IFS="/" read -r ns rel <<<"$full"
  echo "[*] Helm values for $rel in $ns"
  microk8s helm3 get values -n "$ns" "$rel" >"$OUT/helm_${ns}_${rel}_values.yaml" 2>&1 || true
done

echo "[*] Debug data collected in $OUT"

