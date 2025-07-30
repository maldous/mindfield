TF_DIR         := infra/terraform

ifneq (,$(wildcard .env))
	include .env
	export
	export TF_VAR_cloudflare_api_token := $(CLOUDFLARE_API_TOKEN)
endif

.PHONY: all microk8s terraform install addons calico certs issuers dns storage datastores apply destroy

all: microk8s terraform addons calico certs issuers dns storage # datastores

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

# fallocate -l 512G /var/lib/rook/osd1.img
# qemu-nbd --connect=/dev/nbd0 /var/lib/rook/osd1.img

storage: 
	cd $(TF_DIR) && terraform apply -target=module.rook_operator -auto-approve
	cd $(TF_DIR) && terraform apply -target=module.rook_cluster -auto-approve
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
