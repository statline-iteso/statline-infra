# StatLine — Infra · Agent Context

> Read this first. It explains what this repo is, what it is not, and the rules for working in it.
> Deeper docs:
> - `docs/ARCHITECTURE.md`: every Azure resource, the cluster layout, CI/CD and GitOps, branches
> - `docs/CONVENTIONS.md`: how Terraform, Kubernetes manifests, scripts and workflows are written here
> - `docs/DECISIONS.md`: what we decided, why, current limitations and future improvements
>
> If you change a contract (env var, Secret name, Service name/port, Terraform output, image name), update `docs/ARCHITECTURE.md` in the same change and tell the owner of the affected repo. Add every new decision to `docs/DECISIONS.md`.

## 1. The project in one paragraph

**StatLine** is a web platform for unified sports statistics and forecasts across **NBA**, **NFL** and **Liga MX**. Three Kubernetes CronJobs pull games and box scores from API-Sports (with balldontlie.io and TheSportsDB as fallbacks), normalize them and store them in PostgreSQL, where sport-specific metrics live in a JSONB column validated against a JSON Schema per sport. A Node API exposes catalog, comparison and forecast endpoints; a Python service runs versioned scikit-learn models (logistic regression for match outcome, gradient boosting for player metrics); a React SPA shows it all. Users can build watchlists and get alerts on injuries, thresholds or kick-off. StatLine is **not** a fantasy or betting platform: no fantasy sync, no odds.

ITESO final project, Fall 2026: **Juan Pablo González** (backend, frontend, foundations) and **Ian Rodríguez** (infra, predictions, deployment).

## 2. What this repo is (and isn't)

| Repo | Contains |
|---|---|
| **`statline-infra`** (this one) | **Terraform** for every Azure resource. **k3d** for local clusters. *(planned)* The **GitOps** Helm chart and **Argo CD** applications. Project-wide docs (data model, API design, backlog). |
| `statline-backend` | `services/api` (Node 20, Express, Prisma), `services/ingesta` and `services/predicciones` (Python 3.12), `schemas/`, their Dockerfiles and CI. |
| `statline-frontend` | React 18 SPA (Vite, Tailwind, TanStack Query, Recharts), its Dockerfile (nginx) and CI. |

**Not in this repo:** application code, Prisma migrations (they run from the api image in an initContainer), JSON Schemas.

## 3. Scope

In scope (proposal §1.2):
- one Azure resource group with VNet, AKS 1.30, PostgreSQL Flexible Server, Key Vault, Log Analytics, DNS
- one AKS cluster with namespaces `plataforma`, `statline-staging`, `statline-prod`
- platform charts: ingress-nginx, cert-manager, Argo CD, kube-prometheus-stack, Redis
- per environment: Deployments `web` (2 replicas), `api`, `predicciones`; CronJobs `ingesta-basquetbol`, `ingesta-americano`, `ingesta-futbol`; HPA for api and predicciones; NetworkPolicies; PDBs; SecretProviderClass
- CI on GitHub Actions; CD through GitOps with Argo CD; images on Docker Hub

Out of scope: fantasy-platform sync (ESPN, Yahoo), betting odds, multi-region, service mesh, a second cluster.

## 4. Azure for Students constraints (read before writing Terraform)

- **Credit is finite** (USD 100/year). Burstable SKUs only: nodes `Standard_B2s`, PostgreSQL `B_Standard_B1ms`. AKS `sku_tier = "Free"`.
- **vCPU quota is low** per region; the node pool autoscaler stops at 4 nodes.
- **Allowed regions are set by policy**; `location` is a variable (default `eastus2`). Check the policy before changing it.
- **No secrets in code.** Passwords come from `random_password`, go to Key Vault, and reach pods through the Secrets Store CSI driver.
- `make destroy` at the end of a work session unless the environment must stay up (demo, review).

## 5. Stack

| Concern | Choice |
|---|---|
| IaC | **Terraform** ≥ 1.9, `azurerm` ~> 4.14, `random` ~> 3.6; `kubernetes` ~> 2.33 and `helm` ~> 2.16 providers (configured from module aks). State in Azure Storage with blob-lease locking (`use_azuread_auth`) |
| Kubernetes | **AKS 1.30**, node pool 2→4 × `Standard_B2s`, Azure CNI, Azure network policy, OIDC issuer + workload identity, Key Vault CSI add-on |
| Data | **PostgreSQL 16** Flexible Server `B_Standard_B1ms`, private access only (delegated subnet + private DNS zone) |
| Secrets | **Azure Key Vault** + Secrets Store CSI Driver (`SecretProviderClass`) |
| Ingress | **ingress-nginx** + **cert-manager** (Let's Encrypt) |
| Cache | **Redis 7.4** (own StatefulSet chart, `gitops/charts/redis`, D-16) |
| GitOps | **Argo CD**; Helm chart with `values-staging.yaml` / `values-prod.yaml` |
| Observability | **kube-prometheus-stack** (Prometheus, Grafana), Log Analytics + diagnostic settings |
| Images | **Docker Hub**: `statline/web`, `statline/api`, `statline/predicciones`, `statline/ingesta` (short SHA + SemVer) |
| Local | **k3d** (k3s 1.30) with ingress-nginx |
| CI | **GitHub Actions**; checks: `terraform fmt/validate`, `tflint` (azurerm ruleset), shellcheck, `helm lint` + kubeconform *(with the chart)* |

## 6. Commands

```bash
make bootstrap             # once per subscription: state storage account (local state) + backend.hcl
make plan                  # terraform plan for principal (saved to principal.tfplan)
make apply                 # ⚠ applies the saved plan (asks for confirmation)
make destroy               # ⚠ destroys principal (asks for confirmation)
make output                # principal outputs
make lint                  # fmt check, validate, tflint, shellcheck
make k3d-up / k3d-down     # local cluster with ingress-nginx and the three namespaces
make diagram               # docs/solucion.mmd → docs/solucion.png
```

## 7. Repository layout

```
statline-infra/
├── AGENTS.md · CLAUDE.md · README.md · Makefile · mise.toml
├── docs/                    ARCHITECTURE · CONVENTIONS · DECISIONS · BACKLOG · modelo-datos · api · pendientes · planning/
├── terraform/
│   ├── bootstrap/           state storage account (local state, run once)
│   ├── principal/           the environment: calls the modules below
│   └── modules/
│       ├── red/             VNet, subnets, NSG, private DNS zone            (done)
│       ├── aks/             cluster, identity, CSI add-on                   (done)
│       ├── datos/           PostgreSQL Flexible Server                      (done)
│       ├── seguridad/       Key Vault, secrets, access                      (SL-09)
│       ├── observabilidad/  Log Analytics, diagnostic settings              (SL-10)
│       ├── dns/             DNS zone, A record to the ingress IP            (SL-12)
│       └── plataforma/      namespaces, four helm_release                    (SL-12)
├── gitops/                  (SL-53) Helm chart + values per environment + Argo CD Applications
├── k3d/                     local cluster config
├── scripts/                 backend-config.sh · k3d-up.sh
└── .github/workflows/       ci.yml · (SL-53) cd.yml
```

## 8. Rules for agents

1. **Stay in scope** (§3). If a request needs a new Azure service or a new kind of resource, stop and ask.
2. **Never run `terraform apply`, `terraform destroy`, `make apply`, `make destroy`, `kubectl apply/delete` against AKS, or `az` commands that change resources, without explicit confirmation.** `plan`, `validate`, `tflint` and k3d are fine.
3. **All Azure resources go through Terraform.** If something was clicked in the portal, backport it or delete it.
4. **Budget rules (§4) are hard constraints.** Burstable SKUs, at most 4 nodes, no premium tiers.
5. **No secrets in the repo.** No keys, passwords, connection strings or tokens in `.tf`, `.tfvars`, YAML or workflows. `*.tfvars` with real values and `backend.hcl` are gitignored.
6. **Contracts are shared.** Env vars, Secret names, ports and probes the backend images expect are in the backend's ARCHITECTURE §8. Change them only together with the backend owner.
7. **Kubernetes:** namespaced Roles only, default-deny NetworkPolicies, probes and resource requests/limits on every container, images by immutable tag (never `latest`).
8. Follow `docs/CONVENTIONS.md`. Small PRs, one concern each, with the `terraform plan` summary for infra changes.
9. **Branches:** work on `feature/<issue>-<desc>` or `fix/<issue>-<desc>` from `develop`; PRs into `develop` are squash-merged and say `Closes #N`.
10. **No AI attribution.** Never add yourself as a co-author: no `Co-Authored-By` trailers in commits and no "Generated with …" lines in PR descriptions or issues.

## 9. Timeline (course)

| Sprint | Weeks | Scope |
|---|---|---|
| S0 | 1 | Repos, devcontainers, linters, k3d |
| S1 | 2–3 | Terraform modules (network, AKS, PostgreSQL, Key Vault) and Argo CD |
| S2 | 4–5 | PostgreSQL schema (tables + JSONB), NBA ingestion end to end |
| S3 | 6–7 | Node API, JWT auth, CI/CD |
| S4 | 8–9 | scikit-learn models in FastAPI, React views, all three sports |
| S5 | 10–11 | Prometheus, Grafana, HPA, resilience policies |
| S6 | 12 | Quality pass, smoke tests, delivery and defense |

## 10. Glossary

- **principal**: the Terraform stack with the whole environment. **bootstrap**: the stack that creates the state storage.
- **Adaptador**: one implementation of `AdaptadorDeporte` per sport (`obtenerPartidos`, `obtenerEstadisticas`, `normalizar`).
- **Métricas**: the JSONB column of `EstadisticaJugadorPartido`, validated against `schemas/<deporte>.schema.json`.
- **Modelo activo**: the one `ModeloPrediccion` row per sport and inference type with `activo = true`.
