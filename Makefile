# StatLine infra. Every destructive or billable target shows the plan and asks first;
# CONFIRM=yes skips the prompt (CI only).
SHELL := bash
.SHELLFLAGS := -euo pipefail -c
TF := terraform
PRINCIPAL := terraform/principal
BOOTSTRAP := terraform/bootstrap
# AWS Learner Lab (D-38). The lab only allows us-east-1; `override` so neither env nor CLI changes it.
override AWS_REGION := us-east-1
export AWS_REGION
# Locally every target uses the statline-lab profile (make creds writes it), never [default], which
# belongs to another project on this machine. CI (CI=true) uses the AWS_* secrets from make creds.
ifndef CI
AWS_PROFILE ?= statline-lab
export AWS_PROFILE
endif

.PHONY: help creds check-creds bootstrap backend-config init plan apply secrets apply-eks kubeconfig destroy output fmt validate tflint helm-lint helm-validate lint k3d-up k3d-down k3d-deploy smoke diagram

help: ## List targets
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  %-16s %s\n",$$1,$$2}'

creds: ## Paste the lab "AWS CLI" block → profile statline-lab + statline-infra secrets (FROM=clipboard; SKIP_GH=1: local only)
	@scripts/lab-creds.sh

check-creds: ## Fail early if the lab credentials are missing or expired
	@scripts/check-creds.sh

bootstrap: check-creds ## Once per lab account: S3 state bucket + ingress Elastic IP (local state), then backend.hcl
	$(TF) -chdir=$(BOOTSTRAP) init -input=false
	@# Align the local state with the lab account: archive another account's state, adopt an existing bucket or IP.
	scripts/bootstrap-account.sh
	$(TF) -chdir=$(BOOTSTRAP) plan -input=false -out=bootstrap.tfplan
	@[[ "$${CONFIRM:-}" == "yes" ]] || { read -rp "Apply the bootstrap plan above (S3 bucket: cents; Elastic IP: ~USD 3.60/month)? [y/N] " a; [[ "$$a" == y ]]; }
	$(TF) -chdir=$(BOOTSTRAP) apply -input=false bootstrap.tfplan
	@rm -f $(BOOTSTRAP)/bootstrap.tfplan
	$(MAKE) --no-print-directory backend-config

backend-config: ## Write terraform/principal/backend.hcl from the bootstrap outputs
	scripts/backend-config.sh

init: check-creds ## terraform init for the principal stack (remote state in the bootstrap bucket)
	@test -f $(PRINCIPAL)/backend.hcl || { echo "Missing backend.hcl: run make bootstrap or make backend-config"; exit 1; }
	@acct=$$(aws sts get-caller-identity --query Account --output text); \
	  grep -q "statline-tfstate-$$acct\"" $(PRINCIPAL)/backend.hcl || { \
	  echo "backend.hcl is not for lab account $$acct (new lab account?): run make backend-config"; exit 1; }
	$(TF) -chdir=$(PRINCIPAL) init -input=false -reconfigure -backend-config=backend.hcl

plan: init ## Plan the principal stack
	$(TF) -chdir=$(PRINCIPAL) plan -input=false -out=principal.tfplan

apply: plan ## ⚠ Apply the saved plan (creates billable resources)
	@[[ "$${CONFIRM:-}" == "yes" ]] || { read -rp "Apply this plan? [y/N] " a; [[ "$$a" == y ]]; }
	$(TF) -chdir=$(PRINCIPAL) apply -input=false principal.tfplan
	@# The parameters exist now: API keys and Sentry DSNs from the Keychain (RUNBOOK 2.2). Never in CI.
	@[[ -n "$${CI:-}" ]] || scripts/set-secrets.sh

secrets: check-creds ## API keys and Sentry DSNs into SSM (Keychain, asks once), then sync and restart pods (ASK=1: ask again)
	@scripts/set-secrets.sh

# module.red is targeted as a whole: -target=module.eks alone pulls in only what eks references (VPC,
# subnets), not the internet gateway and route tables, and nodes without a route out never join.
apply-eks: init ## ⚠ First apply only: create the network and module eks (providers need the cluster, see README)
	$(TF) -chdir=$(PRINCIPAL) plan -input=false -target=module.red -target=module.eks -out=eks.tfplan
	@[[ "$${CONFIRM:-}" == "yes" ]] || { read -rp "Apply the EKS cluster plan (bills ~USD 0.30/h with the rest until make destroy)? [y/N] " a; [[ "$$a" == y ]]; }
	$(TF) -chdir=$(PRINCIPAL) apply -input=false eks.tfplan
	@rm -f $(PRINCIPAL)/eks.tfplan

kubeconfig: check-creds ## Write the eks-statline context to ~/.kube/config
	aws eks update-kubeconfig --name statline --alias eks-statline

destroy: init ## ⚠ Destroy the principal stack (bootstrap bucket and Elastic IP stay)
	$(TF) -chdir=$(PRINCIPAL) plan -destroy -input=false
	@[[ "$${CONFIRM:-}" == "yes" ]] || { read -rp "Destroy everything above? [y/N] " a; [[ "$$a" == y ]]; }
	@# Argo CD Applications and ExternalSecrets go first, while their controllers can clear their finalizers.
	scripts/vaciar-gitops.sh
	@# The ingress NLB is created by the cluster, not Terraform: remove the charts, wait for it to go.
	$(TF) -chdir=$(PRINCIPAL) destroy -input=false -auto-approve -target=module.plataforma
	scripts/esperar-nlb.sh
	$(TF) -chdir=$(PRINCIPAL) destroy -input=false -auto-approve

output: ## Show principal outputs
	$(TF) -chdir=$(PRINCIPAL) output

fmt: ## terraform fmt -recursive
	$(TF) fmt -recursive terraform

validate: ## terraform validate without a backend
	for d in $(BOOTSTRAP) $(PRINCIPAL); do $(TF) -chdir=$$d init -backend=false -input=false >/dev/null && $(TF) -chdir=$$d validate; done

tflint: ## tflint with the aws ruleset
	cd terraform && tflint --init && tflint --recursive --config "$$PWD/.tflint.hcl"

# Helm: values files are the environments; the defaults file alone is not renderable (image tags are required).
VALUES := $(wildcard gitops/charts/statline/values-*.yaml)
K8S_VERSION := 1.35.0
# Built-in schemas, then the datree CRDs catalog (ExternalSecret, ClusterSecretStore, ClusterIssuer, Argo CD).
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

# Smoke checks from your machine, in a throwaway pod (same script as the smoke-test Job). Not run by CI.
# Refuses unless the current context is a k3d-* or eks-statline* cluster. The release defaults to statline-<ENV>;
# k3d-deploy installs it as "statline", so: make smoke ENV=staging RELEASE=statline
RELEASE ?= statline-$(ENV)
SMOKE_IMAGE := curlimages/curl:8.11.1
SMOKE_OVERRIDES = {"spec":{"automountServiceAccountToken":false,"securityContext":{"runAsNonRoot":true,"runAsUser":100,"runAsGroup":101,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"statline-smoke","securityContext":{"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"capabilities":{"drop":["ALL"]}},"env":[{"name":"SMOKE_WEB","value":"http://$(RELEASE)-web"},{"name":"SMOKE_API","value":"http://$(RELEASE)-api"},{"name":"SMOKE_PREDICCIONES","value":"http://$(RELEASE)-predicciones"}]}]}}

smoke: ## In-cluster smoke checks: make smoke ENV=staging|prod [RELEASE=...] (k3d-* or eks-statline* contexts only)
	@case "$(ENV)" in staging|prod) ;; *) echo "Set ENV=staging or ENV=prod"; exit 1;; esac
	@ctx=$$(kubectl config current-context); case "$$ctx" in k3d-*|eks-statline*) ;; *) echo "Refusing: current context is '$$ctx', not k3d-* or eks-statline*"; exit 1;; esac
	kubectl run statline-smoke --namespace statline-$(ENV) --rm -i --restart=Never --image=$(SMOKE_IMAGE) --labels=statline.io/smoke=true --override-type=strategic --overrides='$(SMOKE_OVERRIDES)' -- sh -s < gitops/charts/statline/files/smoke-test.sh

diagram: ## Render docs/solucion.mmd → docs/solucion.png
	npx -y @mermaid-js/mermaid-cli@11.4.0 -i docs/solucion.mmd -o docs/solucion.png -b white -w 1600
