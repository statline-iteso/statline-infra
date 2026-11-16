# StatLine infra. Every destructive or billable target shows the plan and asks first;
# CONFIRM=yes skips the prompt (CI only).
SHELL := bash
.SHELLFLAGS := -euo pipefail -c
TF := terraform
PRINCIPAL := terraform/principal
BOOTSTRAP := terraform/bootstrap

.PHONY: help bootstrap backend-config init plan apply destroy output fmt validate tflint lint k3d-up k3d-down diagram

help: ## List targets
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  %-16s %s\n",$$1,$$2}'

bootstrap: ## Once per subscription: state storage account (local state)
	$(TF) -chdir=$(BOOTSTRAP) init -input=false
	$(TF) -chdir=$(BOOTSTRAP) apply
	$(MAKE) backend-config

backend-config: ## Write terraform/principal/backend.hcl from the bootstrap outputs
	scripts/backend-config.sh

init: ## terraform init for the principal stack (remote state)
	@test -f $(PRINCIPAL)/backend.hcl || { echo "Missing backend.hcl: run make bootstrap or make backend-config"; exit 1; }
	$(TF) -chdir=$(PRINCIPAL) init -input=false -backend-config=backend.hcl

plan: init ## Plan the principal stack
	$(TF) -chdir=$(PRINCIPAL) plan -input=false -out=principal.tfplan

apply: plan ## ⚠ Apply the saved plan (creates billable resources)
	@[[ "$${CONFIRM:-}" == "yes" ]] || { read -rp "Apply this plan? [y/N] " a; [[ "$$a" == y ]]; }
	$(TF) -chdir=$(PRINCIPAL) apply -input=false principal.tfplan

destroy: init ## ⚠ Destroy the principal stack
	$(TF) -chdir=$(PRINCIPAL) plan -destroy -input=false
	@[[ "$${CONFIRM:-}" == "yes" ]] || { read -rp "Destroy everything above? [y/N] " a; [[ "$$a" == y ]]; }
	$(TF) -chdir=$(PRINCIPAL) destroy -input=false -auto-approve

output: ## Show principal outputs
	$(TF) -chdir=$(PRINCIPAL) output

fmt: ## terraform fmt -recursive
	$(TF) fmt -recursive terraform

validate: ## terraform validate without a backend
	for d in $(BOOTSTRAP) $(PRINCIPAL); do $(TF) -chdir=$$d init -backend=false -input=false >/dev/null && $(TF) -chdir=$$d validate; done

tflint: ## tflint with the azurerm ruleset
	cd terraform && tflint --init && tflint --recursive --config "$$PWD/.tflint.hcl"

lint: ## fmt check + validate + tflint + shellcheck
	$(TF) fmt -recursive -check terraform
	$(MAKE) validate tflint
	shellcheck scripts/*.sh

k3d-up: ## Local cluster (k3d) with ingress on :8080
	scripts/k3d-up.sh

k3d-down: ## Delete the local cluster
	k3d cluster delete statline

diagram: ## Render docs/solucion.mmd → docs/solucion.png
	npx -y @mermaid-js/mermaid-cli@11.4.0 -i docs/solucion.mmd -o docs/solucion.png -b white -w 1600
