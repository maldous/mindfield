.PHONY: help install build reset

.DEFAULT_GOAL := help
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
TF_DIR := infra/terraform
TF = cd $(TF_DIR) && terraform

ifneq ("$(wildcard .env)","")
include .env
export
export TF_VAR_cloudflare_api_token := $(CLOUDFLARE_API_TOKEN)
endif

NET := calico cert_manager cert_issuers external_dns
DATA := minio_operator minio_tenant postgres redis pgbouncer postgraphile

help: ## list commands
	@grep -Eh '^[a-zA-Z][a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) \
	| awk 'BEGIN{FS=":.*## "}{printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

install: ## install MicroK8s, Ceph, Terraform, Addons, Data, Network
	microk8s status --wait-ready
	microk8s config > $$HOME/.kube/config
	sudo microceph cluster bootstrap
	sudo microceph disk add loop,100G,3
	sudo microk8s enable rook-ceph
	sudo microk8s connect-external-ceph
	$(TF) init -upgrade
	$(TF) apply -auto-approve -target=module.microk8s_addons
	@for m in $(NET); do $(TF) apply -auto-approve -target=module.$$m; done
	@for m in $(DATA); do $(TF) apply -auto-approve -target=module.$$m; done
	microk8s status --wait-ready

build: ## (re)apply everything
	$(TF) apply -auto-approve

reset: ## destroy everything
	$(TF) destroy -auto-approve
