# Infra Conventions

Rules for Terraform, Kubernetes manifests, scripts and workflows in this repo. If one gets in the way, change it here in a PR and say why. Don't silently ignore it.

## 1. Terraform

### 1.1 Structure
- Root stacks (`bootstrap`, `principal`) have `versions.tf` (or the `terraform {}` block), `variables.tf`, `outputs.tf`, `locals.tf` and `main.tf`.
- **One module per concern** in `terraform/modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`. Module names follow the proposal: `red`, `aks`, `datos`, `seguridad`, `observabilidad`, `dns`, `plataforma`.
- **Plain resources over community modules.** Big registry modules hide what gets created (and what it costs). A community module needs a decision entry.

### 1.2 Versions
- `required_version = ">= 1.9"`. Providers pinned with `~>` (`azurerm ~> 4.14`, `random ~> 3.6`). `.terraform.lock.hcl` committed for root stacks.
- Helm chart versions pinned explicitly in variables; upgrade them in their own PR.

### 1.3 Naming and tags
- Azure naming: `<abbr>-statline[-<thing>]` (`rg-statline`, `vnet-statline`, `aks-statline`, `psql-statline-<suffix>`, `kv-statline-<suffix>`). Globally unique names get the 5-char `random_string.suffix`.
- Terraform addresses: snake_case, by role (`azurerm_subnet.postgres`, not `subnet2`).
- Tags on every taggable resource: `Project`, `Owner`, `ManagedBy`, `Stack`.

### 1.4 Variables and outputs
- Every variable has `type` and `description`; defaults only when sensible; `validation` for SKUs, sizes and CIDRs.
- Every output has a `description`. Secrets are `sensitive = true` and never written to files.
- Real values in `*.auto.tfvars` (gitignored); `terraform.tfvars.example` committed.

### 1.5 Safety and cost
- `prevent_destroy` on the state storage account and the `statline` database.
- Burstable SKUs only (validated). New billable resources need a decision entry with their monthly cost.
- NSG rules have a `description`; no inbound `*` except 80/443 to the ingress.
- Encryption in transit on (`min_tls_version`, `require_secure_transport`).

### 1.6 Workflow
- Before a PR: `make lint` (fmt check, validate, tflint, shellcheck).
- The PR includes the `terraform plan` summary (add/change/destroy). CI posts the full plan as a comment once Azure credentials exist.
- `apply`/`destroy` only through `make`, which shows the plan and asks.

## 2. Kubernetes manifests (Helm chart, SL-53)

- One chart in `gitops/chart/`, values per environment (`values-staging.yaml`, `values-prod.yaml`, `values-local.yaml`). Environment differences live in values only.
- **Labels:** `app.kubernetes.io/name`, `app.kubernetes.io/part-of: statline`, `app.kubernetes.io/component: web|api|predicciones|ingesta`, `app.kubernetes.io/version`. Selectors use only `app.kubernetes.io/name`.
- **Every container:** `resources.requests` (cpu, memory) and `limits.memory`; liveness and readiness probes (not for CronJobs); `securityContext` with `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`.
- **Images by immutable tag** (short SHA or `vX.Y.Z`); never `latest`. `cd.yml` is the only writer of image tags.
- Config through ConfigMaps (`envFrom`); secrets only from the SecretProviderClass-synced Secret.
- **NetworkPolicies:** each namespace starts with `default-deny-ingress`; each allow policy has a comment saying who needs it.
- Validate: `helm lint` and `helm template … | kubeconform -strict -summary`.

## 3. Scripts and Makefile

- Bash with `set -euo pipefail`, `shellcheck`-clean, print what they're about to do.
- Destructive or billable targets show the plan and ask `[y/N]`; `CONFIRM=yes` skips the prompt (CI only).
- Make targets are the single entry point; workflows call `make` instead of duplicating commands where possible.

## 4. GitHub Actions

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | push to `main`/`develop`, every PR | fmt, validate, tflint, shellcheck; `plan` + PR comment when Azure secrets exist |
| `cd.yml` *(SL-53)* | push to `develop`/`main`, `release/*` | receives the image tag from the app repos (`repository_dispatch`) and commits it to `gitops/values-<env>.yaml` |

- Azure login with **OIDC** (`ARM_USE_OIDC`), never a client secret.
- `concurrency` group per workflow and ref.
- Third-party actions pinned to a major version; pin by commit SHA before the final delivery (SL-61).

## 5. Git and PRs

- Branches from `develop`: `feature/<issue>-<desc>`, `fix/<issue>-<desc>`; `release/vX.Y.Z`, `hotfix/vX.Y.Z` as in ARCHITECTURE §7.
- Conventional Commits: `feat(aks): enable the Key Vault CSI add-on`.
- PR description: what, why, `terraform plan` summary, cost impact, contract changes, and `Closes #N`.
- `feature/*` and `fix/*` are **squash-merged**; `release/*` and `hotfix/*` use a **merge commit**.
- Docs move with code: contracts in `ARCHITECTURE.md`, decisions in `DECISIONS.md`.
- **No AI attribution** in commits, PRs or issues.
