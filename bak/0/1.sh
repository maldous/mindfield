#!/usr/bin/env bash
set -euo pipefail
snap remove microk8s --purge || true
snap remove microceph --purge || true
snap install microk8s --classic
microk8s status --wait-ready
mkdir -p ~/.kube
microk8s config > ~/.kube/config
microk8s enable community
microk8s enable rook-ceph
snap install microceph
modprobe ceph
microceph cluster bootstrap
microceph disk add loop,100G,3    
ceph osd pool create microk8s-rbd0 32
ceph osd pool application enable microk8s-rbd0 rbd
ceph osd pool create microk8s-cephfs-meta 32
ceph osd pool application enable microk8s-cephfs-meta cephfs
ceph osd pool create microk8s-cephfs-data 64
ceph osd pool application enable microk8s-cephfs-data cephfs
ceph fs new microk8sfs microk8s-cephfs-meta microk8s-cephfs-data
CONF=$(find /var/snap/microceph -name ceph.conf | head -n1)
KEYRING=$(find /var/snap/microceph -name ceph.client.admin.keyring | head -n1)
microk8s connect-external-ceph --ceph-conf "$CONF" --keyring "$KEYRING" --rbd-pool microk8s-rbd0
microk8s enable registry --storageclass cephfs
microk8s kubectl patch storageclass ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
microk8s kubectl -n container-registry rollout status deployment/registry --timeout=300s
