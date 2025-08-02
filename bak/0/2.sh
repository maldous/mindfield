#!/usr/bin/env bash
set -euo pipefail
microk8s enable minio -s ceph-rbd -c 20Gi
microk8s kubectl -n minio-operator rollout status deployment/minio-operator --timeout=300s
microk8s enable cloudnative-pg
microk8s kubectl delete sc microk8s-hostpath
cat <<'EOF' | microk8s kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster
  namespace: default
spec:
  instances: 1
  storage:
    size: 10Gi
    storageClass: ceph-rbd
  bootstrap:
    initdb:
      owner: mindfield
      database: mindfield
      encoding: UTF8
EOF
microk8s kubectl -n default wait cluster/pg-cluster --for=condition=Ready --timeout=300s
PG_POD=$(microk8s kubectl -n default get pods -l cnpg.io/cluster=pg-cluster -o jsonpath='{.items[0].metadata.name}')
PG_HOST=pg-cluster-rw.default.svc.cluster.local
microk8s kubectl -n default exec -i "$PG_POD" -- psql -U postgres <<'EOF'
ALTER ROLE mindfield WITH PASSWORD 'mindfield';
CREATE ROLE keycloak LOGIN PASSWORD 'keycloak';
CREATE DATABASE keycloak OWNER keycloak ENCODING 'UTF8';
EOF
microk8s kubectl -n default create secret generic mindfield-pg --dry-run=client -o yaml --from-literal=username=mindfield --from-literal=password=mindfield --from-literal=database=mindfield | microk8s kubectl apply -f -
microk8s kubectl -n default create secret generic keycloak-pg --dry-run=client -o yaml --from-literal=username=keycloak --from-literal=password=keycloak --from-literal=database=keycloak | microk8s kubectl apply -f -
microk8s helm repo add bitnami https://charts.bitnami.com/bitnami 
microk8s helm repo update
microk8s helm upgrade --install redis bitnami/redis --set architecture=standalone --set auth.enabled=false --set master.persistence.storageClass=ceph-rbd --set master.persistence.size=3Gi
MINIO_HOST=microk8s-hl.minio-operator.svc.cluster.local
MINIO_ACCESS=$(microk8s kubectl -n minio-operator get secret microk8s-user-1 -o jsonpath='{.data.CONSOLE_ACCESS_KEY}' | base64 -d)
MINIO_SECRET=$(microk8s kubectl -n minio-operator get secret microk8s-user-1 -o jsonpath='{.data.CONSOLE_SECRET_KEY}' | base64 -d)
microk8s kubectl run mc-bucket --image=minio/mc --restart=Never --rm -it --env "MC_HOST_local=http://${MINIO_ACCESS}:${MINIO_SECRET}@${MINIO_HOST}:9000" --command -- mc mb local/keycloak-bucket --ignore-existing
helm upgrade --install keycloak bitnami/keycloak \
  --set auth.adminUser=admin \
  --set auth.adminPassword=changeme \
  --set postgresql.enabled=false \
  --set externalDatabase.host=${PG_HOST} \
  --set externalDatabase.user=keycloak \
  --set externalDatabase.password=keycloak \
  --set externalDatabase.database=keycloak \
  --set cache.enabled=true \
  --set cache.type=redis \
  --set cache.redis.host=redis-master.default.svc.cluster.local \
  --set persistence.size=5Gi \
  --set persistence.storageClass=ceph-rbd \
  --set extraEnv[0].name=KC_SPI_STORAGE_S3_BUCKET \
  --set extraEnv[0].value=keycloak-bucket \
  --set extraEnv[1].name=KC_SPI_STORAGE_S3_ENDPOINT \
  --set extraEnv[1].value="http://${MINIO_HOST}:9000" \
  --set extraEnv[2].name=KC_SPI_STORAGE_S3_ACCESSKEY \
  --set extraEnv[2].value=${MINIO_ACCESS} \
  --set extraEnv[3].name=KC_SPI_STORAGE_S3_SECRETKEY \
  --set extraEnv[3].value=${MINIO_SECRET}
microk8s kubectl -n default wait --for=condition=Ready pod/keycloak-0 --timeout=300s
