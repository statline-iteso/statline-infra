# StatLine infra. Every destructive or billable target shows the plan and asks first;
# CONFIRM=yes skips the prompt (CI only).
SHELL := bash
.SHELLFLAGS := -euo pipefail -c
TF := terraform
PRINCIPAL := terraform/principal
BOOTSTRAP := terraform/bootstrap

.PHONY: help bootstrap backend-config init plan apply apply-aks destroy output fmt validate tflint helm-lint helm-validate lint k3d-up k3d-down k3d-deploy diagram

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

apply-aks: init ## ⚠ First apply only: create module aks alone (providers need the cluster, see README)
	$(TF) -chdir=$(PRINCIPAL) plan -input=false -target=module.aks -out=aks.tfplan
	@[[ "$${CONFIRM:-}" == "yes" ]] || { read -rp "Apply the AKS cluster plan? [y/N] " a; [[ "$$a" == y ]]; }
	$(TF) -chdir=$(PRINCIPAL) apply -input=false aks.tfplan

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

# Helm: values files are the environments; the defaults file alone is not renderable (image tags are required).
VALUES := $(wildcard gitops/charts/statline/values-*.yaml)
K8S_VERSION := 1.30.6
# Built-in schemas, then the datree CRDs catalog (SecretProviderClass, ClusterIssuer, Argo CD).
KUBECONFORM_FLAGS := -strict -summary -ignore-missing-schemas -kubernetes-version $(K8S_VERSION) \
	-schema-location default \
	-schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

helm-lint: ## helm lint --strict: redis, and statline with each environment values file
	helm lint --strict gitops/charts/redis
	@for f in $(VALUES); do echo "helm lint statline -f $$f"; helm lint --strict gitops/charts/statline -f $$f; done

helm-validate: ## helm template | kubeconform -strict for every chart and environment (monitoring off and on); also the Argo CD and plataforma manifests
	@for f in $(VALUES); do echo "validate statline $$f"; helm template statline gitops/charts/statline -f $$f | kubeconform $(KUBECONFORM_FLAGS); done
	@for f in $(VALUES); do echo "validate statline $$f (monitoring on)"; helm template statline gitops/charts/statline -f $$f --set monitoring.enabled=true | kubeconform $(KUBECONFORM_FLAGS); done
	helm template redis gitops/charts/redis | kubeconform $(KUBECONFORM_FLAGS)
	kubeconform $(KUBECONFORM_FLAGS) gitops/argocd/project.yaml gitops/argocd/root.yaml gitops/argocd/apps/*.yaml gitops/plataforma/*.yaml

lint: ## fmt check + validate + tflint + shellcheck + helm-lint + helm-validate
	$(TF) fmt -recursive -check terraform
	$(MAKE) validate tflint
	shellcheck scripts/*.sh
	$(MAKE) helm-lint helm-validate

k3d-up: ## Local cluster (k3d) with ingress on :8080
	scripts/k3d-up.sh

k3d-down: ## Delete the local cluster
	k3d cluster delete statline

k3d-deploy: ## Install redis (plataforma) and the chart with values-k3d (statline-staging); images must be imported first
	@ctx=$$(kubectl config current-context); case "$$ctx" in k3d-*) ;; *) echo "Refusing: current context is '$$ctx', not k3d-*"; exit 1;; esac
	helm upgrade --install redis gitops/charts/redis --namespace plataforma --wait
	helm upgrade --install statline gitops/charts/statline --namespace statline-staging -f gitops/charts/statline/values-k3d.yaml --wait

diagram: ## Render docs/solucion.mmd → docs/solucion.png
	npx -y @mermaid-js/mermaid-cli@11.4.0 -i docs/solucion.mmd -o docs/solucion.png -b white -w 1600
