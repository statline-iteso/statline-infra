# StatLine — Infra · Agent Context

> Read this first. It explains what this repo is, what it is not, and the rules for working in it.
> Deeper docs:
> - `docs/ARCHITECTURE.md`: every AWS resource, the cluster layout, CI/CD and GitOps, branches
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
| **`statline-infra`** (this one) | **Terraform** for every AWS resource. **k3d** for local clusters. The **GitOps** Helm charts and **Argo CD** applications. Project-wide docs (data model, API design, backlog). |
| `statline-backend` | `services/api` (Node 20, Express, Prisma), `services/ingesta` and `services/predicciones` (Python 3.12), `schemas/`, their Dockerfiles and CI. |
| `statline-frontend` | React 18 SPA (Vite, Tailwind, TanStack Query, Recharts), its Dockerfile (nginx) and CI. |

**Not in this repo:** application code, Prisma migrations (they run from the api image in an initContainer), JSON Schemas.

## 3. Scope

In scope (proposal §1.2, moved from Azure to AWS by D-38):
- on the AWS Learner Lab: one VPC, EKS, RDS PostgreSQL, SSM Parameter Store, CloudWatch logs, an Elastic IP for the ingress (hosts on nip.io)
- one EKS cluster with namespaces `plataforma`, `statline-staging`, `statline-prod`
- platform charts: ingress-nginx, cert-manager, Argo CD, kube-prometheus-stack, External Secrets; Redis as our own chart
- per environment: Deployments `web` (2 replicas), `api`, `predicciones`; CronJobs `ingesta-basquetbol`, `ingesta-americano`, `ingesta-futbol`; HPA for api and predicciones; NetworkPolicies; PDBs; ExternalSecret
- CI on GitHub Actions; CD through GitOps with Argo CD; images on Docker Hub

Out of scope: fantasy-platform sync (ESPN, Yahoo), betting odds, multi-region, service mesh, a second cluster.

## 4. AWS Learner Lab constraints (read before writing Terraform)

- **Budget is finite** (USD 50 for the lab). Burstable only: nodes `t3.medium` (the lab allows up to `*.large`), RDS `db.t3.micro`. EKS in standard support only (`upgrade_policy = STANDARD`): extended support costs 6×.
- **No new IAM:** no roles, OIDC providers, IRSA or Pod Identity. The cluster, the nodes and every pod that calls AWS use the pre-created `LabRole`. Anything that needs its own role (Cluster Autoscaler, the AWS Load Balancer Controller, EBS CSI) is out, or uses the node role.
- **us-east-1 only** (the Makefile pins `AWS_REGION`). EKS does not support us-east-1e.
- **The lab's SCP denies some reads,** for example `s3:GetBucketObjectLockConfiguration`, which breaks `aws_s3_bucket`: S3 buckets use `awscc_s3_bucket`. The lab also denies reading its own IAM policies, so permission gaps show up on apply.
- **Credentials expire with the session.** `make creds` at the start of each one: it writes the `statline-lab` profile (never `[default]`) and the `AWS_*` secrets of this repo for CI.
- **No secrets in code.** Passwords come from `random_password`, go to SSM SecureStrings, and reach pods through External Secrets.
- `make destroy` at the end of every session unless the environment must stay up (demo, review): the cluster bills about USD 0.30/h.

## 5. Stack

| Concern | Choice |
|---|---|
| IaC | **Terraform** ≥ 1.10, `aws` ~> 6.0, `awscc` ~> 1.0 (state bucket), `random` ~> 3.6; `kubernetes` ~> 2.33 and `helm` ~> 2.16 providers (configured from module eks, token from `aws eks get-token`). State in S3 with native locking (`use_lockfile`) |
| Kubernetes | **EKS 1.35** on `LabRole`, managed node group 2 × `t3.medium` (fixed), VPC CNI with network policies and prefix delegation, metrics-server addon |
| Data | **PostgreSQL 16** on RDS `db.t3.micro`, private subnets only, 5432 from the cluster security group |
| Secrets | **SSM Parameter Store** SecureStrings + **External Secrets** (`ClusterSecretStore` with the node role) |
| Ingress | **ingress-nginx** as an NLB on the bootstrap Elastic IP + **cert-manager** (Let's Encrypt); hosts on nip.io |
| Cache | **Redis 7.4** (own StatefulSet chart, `gitops/charts/redis`, D-26) |
| GitOps | **Argo CD**; Helm chart with `values-staging.yaml` / `values-prod.yaml` |
| Observability | **kube-prometheus-stack** (Prometheus, Grafana), CloudWatch logs for the EKS control plane and RDS |
| Images | **Docker Hub**, namespace `pardosito` (repo variable `DOCKERHUB_NAMESPACE` in the app repos): `pardosito/{web,api,predicciones,ingesta}` (short SHA + SemVer) |
| Local | **k3d** (k3s 1.35) with ingress-nginx |
| CI | **GitHub Actions**; checks: `terraform fmt/validate`, `tflint` (aws ruleset), shellcheck, `helm lint` + kubeconform; an informational `terraform plan` comment on PRs with the lab keys |

## 6. Commands

```bash
make creds                 # start of every lab session: lab keys → profile statline-lab + CI secrets
make check-creds           # are they still valid?
make bootstrap             # once per lab account: S3 state bucket + ingress Elastic IP (local state) + backend.hcl
make apply-eks             # ⚠ first apply only: the EKS cluster and nodes
make plan                  # terraform plan for principal (saved to principal.tfplan)
make apply                 # ⚠ applies the saved plan (asks for confirmation), then runs make secrets
make datos ENV=prod        # after Argo CD syncs: backfill live data (+ demo data in staging), then models
make secrets               # API keys and Sentry DSNs into SSM from the Keychain (asks once); ASK=1 asks again
make kubeconfig            # context eks-statline
make destroy               # ⚠ destroys principal (asks; waits for the ingress NLB before the VPC)
make output                # principal outputs
make lint                  # fmt check, validate, tflint, shellcheck, helm lint, kubeconform
make k3d-up / k3d-down     # local cluster with ingress-nginx and the three namespaces
make diagram               # docs/solucion.mmd → docs/solucion.png
```

## 7. Repository layout

```
statline-infra/
├── AGENTS.md · CLAUDE.md · README.md · Makefile · mise.toml
├── docs/                    ARCHITECTURE · CONVENTIONS · DECISIONS · BACKLOG · RUNBOOK · modelo-datos · api · pendientes · planning/
├── terraform/
│   ├── bootstrap/           S3 state bucket (awscc) + ingress Elastic IP (local state)
│   ├── principal/           the environment: calls the modules below
│   └── modules/
│       ├── red/             VPC, public and private subnets, internet gateway
│       ├── eks/             cluster, node group, addons (LabRole)
│       ├── datos/           RDS PostgreSQL
│       ├── seguridad/       SSM parameters
│       ├── observabilidad/  CloudWatch log groups
│       └── plataforma/      namespaces, five helm_release, database Job
├── gitops/                  Helm charts (statline, redis) + values per environment + Argo CD Applications
├── k3d/                     local cluster config
├── scripts/                 lab-creds.sh · check-creds.sh · bootstrap-account.sh · backend-config.sh · esperar-nlb.sh · vaciar-gitops.sh · set-secrets.sh · cargar-datos.sh · k3d-up.sh · bump-image-tags.sh · smoke.sh
└── .github/workflows/       ci.yml · cd.yml (tag bump PRs) · auto-merge.yml
```

## 8. Rules for agents

1. **Stay in scope** (§3). If a request needs a new AWS service or a new kind of resource, stop and ask.
2. **Never run `terraform apply`, `terraform destroy`, `make apply`, `make destroy`, `kubectl apply/delete` against EKS, or `aws` commands that change resources, without explicit confirmation.** Never use the `[default]` AWS profile or a non-StatLine kubectl context. `plan`, `validate`, `tflint` and k3d are fine.
3. **All AWS resources go through Terraform.** If something was clicked in the console, backport it or delete it.
4. **Budget rules (§4) are hard constraints.** Burstable instances, at most 4 nodes, standard support only, no NAT gateway.
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
| S1 | 2–3 | Terraform modules (network, cluster, PostgreSQL, secrets) and Argo CD |
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
