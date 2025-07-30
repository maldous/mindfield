TF_DIR         := infra/terraform

ifneq (,$(wildcard .env))
	include .env
	export
	export TF_VAR_cloudflare_api_token := $(CLOUDFLARE_API_TOKEN)
endif

.PHONY: all microk8s terraform install addons calico certs issuers dns microceph minio datastores apply destroy

all: microk8s terraform addons calico certs issuers dns microceph minio # datastores

install: microk8s terraform

microk8s:
	microk8s status --wait-ready
	microk8s config > ${HOME}/.kube/config

terraform:
	cd $(TF_DIR) && terraform init

addons:
	cd $(TF_DIR) && terraform apply -target=module.microk8s_addons -auto-approve
	microk8s status --wait-ready

calico:
	cd $(TF_DIR) && terraform apply -target=module.calico -auto-approve

certs:
	cd $(TF_DIR) && terraform apply -target=module.cert_manager -auto-approve

issuers:
	cd $(TF_DIR) && terraform apply -target=module.cert_issuers -auto-approve

dns:
	cd $(TF_DIR) && terraform apply -target=module.external_dns -auto-approve

microceph:
	sudo microceph cluster bootstrap
	sudo microceph disk add loop,100G,3
	sudo microk8s enable rook-ceph
	sudo microk8s connect-external-ceph
	microk8s kubectl delete pods -n rook-ceph -l app=csi-rbdplugin --ignore-not-found=true
	microk8s kubectl delete pods -n rook-ceph -l app=csi-rbdplugin-provisioner --ignore-not-found=true

minio: 
	cd $(TF_DIR) && terraform apply -target=module.minio_operator -auto-approve
	cd $(TF_DIR) && terraform apply -target=module.minio_tenant -auto-approve

datastores:
	cd $(TF_DIR) && terraform apply -target=module.postgres -auto-approve
	cd $(TF_DIR) && terraform apply -target=module.redis -auto-approve
	cd $(TF_DIR) && terraform apply -target=module.pgbouncer -auto-approve
	cd $(TF_DIR) && terraform apply -target=module.postgraphile -auto-approve

apply:
	cd $(TF_DIR) && terraform apply -auto-approve

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve
