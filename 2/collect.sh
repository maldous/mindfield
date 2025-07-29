#!/usr/bin/env bash
set -euo pipefail
OUT="diag-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

note(){ echo "### $*" | tee -a "$OUT/summary.txt"; }

note "Cluster basics"
kubectl version -oyaml >"$OUT/kubectl-version.yaml" 2>&1 || true
kubectl get nodes -o wide >"$OUT/nodes.txt"
kubectl get ns --show-labels >"$OUT/namespaces.txt"
kubectl get sc -o wide >"$OUT/storageclasses.txt"
kubectl get pvc -A >"$OUT/pvc.txt"
kubectl get pv >"$OUT/pv.txt"
kubectl get events -A --sort-by=.lastTimestamp >"$OUT/events.txt"

note "Non-running pods"
kubectl get pods -A -o wide | awk 'NR==1 || $4!="Running" && $4!="Completed"' >"$OUT/pods-nonrunning.txt"

note "Namespace labels (Pod Security)"
for ns in apps auth ci data docs gateway messaging observability temporal; do
  kubectl get ns "$ns" -oyaml >"$OUT/ns-$ns.yaml" || true
done

note "Edge cert presence"
for ns in auth ci gateway apps data messaging observability temporal; do
  mkdir -p "$OUT/secrets/$ns"
  kubectl get secret -n "$ns" edge-cert -oyaml >"$OUT/secrets/$ns/edge-cert.yaml" 2>&1 || true
done

note "Postgres & PgBouncer endpoints"
kubectl get svc -A | grep -Ei 'postgres|pgbouncer' >"$OUT/postgres-svcs.txt" || true
kubectl get endpoints -A | grep -Ei 'postgres|pgbouncer' >"$OUT/postgres-endpoints.txt" || true

note "Keycloak details"
kubectl get sts -n auth keycloak -oyaml >"$OUT/keycloak-sts.yaml" 2>&1 || true
kubectl describe pod -n auth keycloak-0 >"$OUT/keycloak-0.describe.txt" 2>&1 || true
kubectl logs -n auth keycloak-0 --tail=1000 >"$OUT/keycloak-0.logs.txt" 2>&1 || true
# dump env for Keycloak container
kc=$(kubectl get pod -n auth -l app.kubernetes.io/name=keycloak -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "${kc:-}" ]; then
  kubectl exec -n auth "$kc" -c keycloak -- printenv >"$OUT/keycloak-env.txt" 2>&1 || true
fi

note "Grafana (init perms)"
gf=$(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "${gf:-}" ]; then
  kubectl get pod -n observability "$gf" -oyaml >"$OUT/grafana-pod.yaml" || true
  for c in init-chown-data grafana grafana-sc-dashboard grafana-sc-datasources; do
    kubectl logs -n observability "$gf" -c "$c" --tail=1000 >"$OUT/grafana-$c.logs.txt" 2>&1 || true
  done
fi
helm -n observability get values kube-prometheus-stack >"$OUT/helm-values-kps.yaml" 2>&1 || true

note "Loki"
kubectl get sts -n observability loki -oyaml >"$OUT/loki-sts.yaml" 2>&1 || true
kubectl describe pod -n observability loki-0 >"$OUT/loki-0.describe.txt" 2>&1 || true
kubectl logs -n observability loki-0 -c loki --tail=2000 >"$OUT/loki.logs.txt" 2>&1 || true
kubectl logs -n observability loki-0 -c loki-sc-rules --tail=500 >"$OUT/loki-sc-rules.logs.txt" 2>&1 || true
helm -n observability get values loki >"$OUT/helm-values-loki.yaml" 2>&1 || true

note "Tempo"
kubectl get svc -n observability | grep -i tempo >"$OUT/tempo-svcs.txt" 2>&1 || true
helm -n observability get values tempo >"$OUT/helm-values-tempo.yaml" 2>&1 || true

note "OTel Collector"
kubectl get ds -n observability opentelemetry-collector -oyaml >"$OUT/otel-ds.yaml" 2>&1 || true
kubectl describe ds -n observability opentelemetry-collector >"$OUT/otel-ds.describe.txt" 2>&1 || true
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --all-containers --tail=2000 >"$OUT/otel.logs.txt" 2>&1 || true
helm -n observability get values opentelemetry-collector >"$OUT/helm-values-otel.yaml" 2>&1 || true

note "Temporal & Elasticsearch"
kubectl get pods -n temporal -o wide >"$OUT/temporal-pods.txt"
kubectl get svc -n temporal >"$OUT/temporal-svcs.txt"
kubectl describe pod -n temporal temporal-schema-1-bnh5d >"$OUT/temporal-schema.describe.txt" 2>&1 || true
kubectl logs -n temporal job/temporal-schema-1 --tail=2000 >"$OUT/temporal-schema.logs.txt" 2>&1 || true
kubectl get sts -n temporal -oyaml >"$OUT/temporal-sts.yaml" 2>&1 || true
helm -n temporal get values temporal >"$OUT/helm-values-temporal.yaml" 2>&1 || true
kubectl describe pod -n temporal elasticsearch-master-0 >"$OUT/es-master-0.describe.txt" 2>&1 || true

note "Kong / Gateway"
kubectl get pods -n gateway -o wide >"$OUT/kong-pods.txt"
kubectl logs -n gateway -l app.kubernetes.io/name=kong --tail=1000 >"$OUT/kong.logs.txt" 2>&1 || true
kubectl get gatewayclass,gateway,httproute,tlsroute,referencegrant -A >"$OUT/gateway-api.txt" 2>&1 || true

note "Helm releases list"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  helm -n "$ns" list >"$OUT/helm-list-$ns.txt" 2>&1 || true
done

note "Done"
tar -czf "$OUT.tgz" "$OUT"
echo "Archive: $OUT.tgz"

