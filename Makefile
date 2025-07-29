TF_DIR         := infra/terraform

.PHONY: all microk8s terraform install addons calico certs secrets dns apply destroy

all: microk8s terraform addons calico certs secrets dns

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

secrets:
	cd $(TF_DIR) && terraform apply -target=module.external_secrets -auto-approve

dns:
	cd $(TF_DIR) && terraform apply -target=module.external_dns -auto-approve

apply:
	cd $(TF_DIR) && terraform apply -auto-approve

destroy:
	cd $(TF_DIR) && terraform destroy -auto-approve
