# Infra Architecture

What runs where, how it gets there, and the contracts with the backend and frontend repos. Items marked **(planned)** are designed but not built yet; each one names its issue.

## 1. Overview

```
                Internet
                   │ 80/443
         ┌─────────▼──────────┐  static public IP (rg-statline) + DNS A record (if dominio)
         │   ingress-nginx    │  TLS from cert-manager (Let's Encrypt)
         └───┬───────────┬────┘
   /         │           │  /api
   ┌─────────▼──┐   ┌────▼──────┐     ┌──────────────┐
   │ web (2)    │   │ api (2–6) │────▶│ predicciones │ (1–4)
   │ nginx SPA  │   │ Node 20   │     │ FastAPI      │
   └────────────┘   └──┬─────┬──┘     └──────┬───────┘
                       │     │ Redis
                       │     ▼               │
   CronJob ingesta-*   │  ┌───────┐          │
   (3 schedules) ──────┼─▶│ PG 16 │◀─────────┘   PostgreSQL Flexible Server, private subnet
        │              └─▶└───────┘
        ▼ HTTPS
   API-Sports · balldontlie.io · TheSportsDB
```

One AKS cluster, three namespaces: `plataforma` (shared charts), `statline-staging` (follows `develop`), `statline-prod` (follows `main`).

## 2. Terraform stacks

| Stack | State | Contains |
|---|---|---|
| `terraform/bootstrap` | local (`terraform.tfstate`, gitignored) | `rg-statline-tfstate`, storage account `ststatlinetf<6>`, container `tfstate`, *Storage Blob Data Contributor* for the caller |
| `terraform/principal` | `tfstate/principal.tfstate` in the bootstrap account, lease-locked | `rg-statline` and the modules below |

`principal` uses `use_azuread_auth = true`: no storage keys anywhere. `make backend-config` writes `backend.hcl` from the bootstrap outputs.

## 3. Modules and resources

| Module | Status | Resources |
|---|---|---|
| `red` | done | `vnet-statline` 10.0.0.0/16 · `snet-aks` 10.0.0.0/20 · `snet-postgres` 10.0.16.0/24 delegated to `Microsoft.DBforPostgreSQL/flexibleServers` · `nsg-statline-aks` (80/443 from Internet) · private DNS zone `statline.private.postgres.database.azure.com` + VNet link |
| `aks` | done | `id-statline-aks` (user-assigned) with *Network Contributor* on `snet-aks` · `aks-statline` 1.30, node pool `system` 2→4 × Standard_B2s, Azure CNI, Azure network policy, service CIDR 10.1.0.0/16, OIDC issuer, workload identity, Key Vault Secrets Store CSI add-on (rotation 5 min) |
| `datos` | done | `psql-statline-<5>` PostgreSQL 16 `B_Standard_B1ms`, 32 GiB auto-grow, 7-day backups, private access only, `require_secure_transport=on` · databases `statline_staging` and `statline_prod` (D-16; destroyed with the server, dump first) · admin password from `random_password` |
| `seguridad` | done | `kv-statline-<5>` Standard, RBAC (`rbac_authorization_enabled`), soft delete 7 days, purge protection off, public access with default Allow (D-18) · *Key Vault Secrets Officer* for the deployer · *Key Vault Secrets User* for the CSI add-on identity · secrets below |
| `observabilidad` | done (SL-10) | `log-statline` Log Analytics, PerGB2018, 30 days retention, daily cap 0.5 GB (`log_analytics_daily_quota_gb`) · one `azurerm_monitor_diagnostic_setting` per entry of `recursos_diagnostico` (`diag-aks`, `diag-postgres`), destination *Dedicated* tables. AKS: `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `cluster-autoscaler`, `guard` + AllMetrics. PostgreSQL: `allLogs` group + AllMetrics. Key Vault: `allLogs` group + AllMetrics |
| `principal` (SL-12) | done | `azurerm_public_ip.ingress` (Standard, Static, `rg-statline`) · `azurerm_role_assignment` Network Contributor on `rg-statline` for the AKS identity · `kubernetes`/`helm` providers from `module.aks.kube_config` |
| `dns` | done (SL-12, only if `dominio` is set) | `azurerm_dns_zone` `dominio` · A records `@` and `staging` → ingress IP (TTL 300) |
| `plataforma` | done (SL-12) | `kubernetes_namespace` ×3 (`plataforma`, `statline-staging`, `statline-prod`, label `statline.io/ambiente`) · `random_password` Grafana · `helm_release`: ingress-nginx 4.15.1, cert-manager v1.21.3, argo-cd 10.11.6, kube-prometheus-stack 92.16.0 — all in `plataforma`. Redis is a StatefulSet in the GitOps chart (D-20) |

Outputs other repos or the chart rely on: `aks_cluster_name`, `resource_group_name`, `aks_oidc_issuer_url`, `key_vault_csi_identity_client_id`, `postgres_fqdn`, `key_vault_name`, `key_vault_uri`, `tenant_id` (SecretProviderClass), `log_analytics_workspace_id`, `log_analytics_workspace_name`, `ingress_public_ip`, `dns_name_servers` (null without `dominio`), `grafana_admin_password` (sensitive). Renaming one is a contract change. Key Vault, PostgreSQL and AKS all send diagnostics to `log-statline`.

### Key Vault secrets (contract)

Names are fixed; the SecretProviderClass (SL-58) and the backend read them by these names. `<env>` is `staging` or `prod`.

| Secret | Value | Per env | Source |
|---|---|---|---|
| `database-url-<env>` | `DATABASE_URL` for `statline_<env>` (admin login, `sslmode=require`) | yes | `module.datos.database_urls` |
| `jwt-secret-<env>` | `JWT_SECRET`, 64 chars | yes | `random_password` |
| `jwt-refresh-secret-<env>` | `JWT_REFRESH_SECRET`, 64 chars | yes | `random_password` |
| `api-sports-key` | `API_SPORTS_KEY` | no (one quota for all envs) | placeholder `set-me`, set out of band; Terraform ignores later changes |
| `balldontlie-api-key` | `BALLDONTLIE_API_KEY` (ingesta NBA fallback) | no | placeholder `set-me`, set out of band before enabling `FALLBACK_HABILITADO`; Terraform ignores later changes |

The Kubernetes Secret `statline-secrets` maps these to the env names the images expect (§5).

### Why private access for PostgreSQL

With a delegated subnet the server has no public endpoint, so the proposal's "firewall rules" are replaced by the network boundary: only the VNet (AKS pods) can reach it. Admin access for humans goes through `kubectl run` with a `postgres:16` client pod or `kubectl port-forward` to a pod (D-06).

## 4. Cluster layout (SL-53 chart, SL-58 values, SL-55 HPA, SL-56 NetworkPolicy and PDB)

### 4.1 Chart layout

| Path | What |
|---|---|
| `gitops/charts/statline/` | the environment chart (`Chart.yaml` v2, 0.1.0). Templates: `_helpers.tpl`, `web.yaml`, `api.yaml`, `predicciones.yaml`, `ingesta.yaml` (ServiceAccount, ConfigMap, 3 CronJobs), `ingress.yaml`, `secrets.yaml`, `dev-postgres.yaml` (k3d only), `smoke-test.yaml` (post-deploy smoke Job, D-33; script in `files/smoke-test.sh`) |
| `gitops/charts/statline/values.yaml` | documented defaults. Not renderable alone: image tags are required |
| `gitops/charts/statline/values-{staging,prod,k3d}.yaml` | one file per environment. Argo CD renders staging and prod; `make k3d-deploy` renders k3d |
| `gitops/charts/redis/` | Redis StatefulSet, Service and ServiceAccount for `plataforma` (D-26) |
| `gitops/argocd/` | `project.yaml` (AppProject `statline`), `root.yaml` (app of apps), `apps/` (statline-staging, statline-prod, redis, plataforma-config) |
| `gitops/plataforma/` | cert-manager `ClusterIssuer`s `letsencrypt-staging` and `letsencrypt-prod` |

Image tags live on `<component>.image.tag` (`web`, `api`, `predicciones`, `ingesta`). The image is `<global.imageRegistry>/<image.repository>:<tag>`, so `docker.io/statline/api:<tag>`. `cd.yml` is the only writer of those paths in `values-staging.yaml` and `values-prod.yaml`.

Naming and labels: objects are named `<release>-<component>` (release `statline-staging` gives `statline-staging-api`), and the CronJobs `<release>-ingesta-<job>`. `app.kubernetes.io/name` is `statline-<component>` so selectors use that label alone (AGENTS.md section 7). Every object also carries `app.kubernetes.io/{instance,part-of,component,version,managed-by}` and `statline.io/environment`.

### 4.2 Objects per environment

| Object | Count | Detail |
|---|---|---|
| Namespace | 3 | `plataforma`, `statline-staging`, `statline-prod` |
| Deployment | 3 per env | `web` (2 replicas), `api`, `predicciones` |
| StatefulSet | 1 | Redis 7 (our own manifest in the GitOps chart, in `plataforma`; not a Bitnami chart, D-26) |
| CronJob | 3 per env | `ingesta-basquetbol` `0 8 * * *` · `ingesta-americano` `0 8 * * 2` · `ingesta-futbol` `0 8 * * 1,5` (UTC) |
| Service | 4 | ClusterIP for web, api, predicciones and Redis |
| Ingress | 1 per env | `/` → web, `/api` → api; TLS via cert-manager |
| HPA | 2 per env | api 2–6 at 70 % CPU; predicciones 1–4 at 75 % CPU |
| ConfigMap | 1 per component | non-secret settings (ports, `PREDICCIONES_URL`, `TEMPORADA_*`, log level) |
| SecretProviderClass | 1 per env | mounts the Key Vault secrets and syncs a Kubernetes Secret `statline-secrets` |
| Namespace | 3 | `plataforma`, `statline-staging`, `statline-prod` (created by `k3d-up` or ops; Argo uses `CreateNamespace=false`) |
| Deployment | 3 per env | `web` (2 replicas), `api` (2, initContainer `migrate`), `predicciones` (1) |
| StatefulSet | 1 | Redis, in `plataforma` (`gitops/charts/redis`) |
| CronJob | 3 per env | `ingesta-basquetbol` `0 8 * * *` · `ingesta-americano` `0 8 * * 2` · `ingesta-futbol` `0 8 * * 1,5` (UTC). `concurrencyPolicy: Forbid`, `backoffLimit: 1`, `activeDeadlineSeconds: 3600` |
| Service | 4 | ClusterIP for web, api and predicciones (port 80 to the container port) and `redis` (6379) |
| Ingress | 1 per env | `/api` → api, `/` → web; class `nginx`; TLS through cert-manager when `ingress.tls.enabled` |
| ServiceAccount | 1 per workload | `automountServiceAccountToken: false` (a values switch per component) |
| ConfigMap | 1 for api, predicciones, ingesta | non-secret settings. Web has no env, so it has no ConfigMap. Changes roll the pods through a `checksum/config` annotation |
| SecretProviderClass or Secret | 1 per env | see 4.3 |
| HPA | 2 per env (staging, prod) | `autoscaling/v2`. api 2–6 at 70 % CPU; predicciones 1–4 at 75 % CPU; scale-down stabilization 300 s. When enabled, the Deployment omits `spec.replicas`. Needs metrics-server (AKS and k3s have it). Disabled in k3d |
| PodDisruptionBudget | 3 per env | web and api `minAvailable: 1`; predicciones `maxUnavailable: 1` (D-31). Disabled for web and api in k3d (single replica) |
| NetworkPolicy | ~10 per env | default-deny ingress and egress, then one allow policy per flow (5.1). Enabled in staging, prod and k3d |
| Job | 1 per env | `<release>-smoke`: post-deploy smoke test, PostSync and Helm hook (D-33). Pod label `statline.io/smoke: "true"` lets it reach web, api and predicciones (NetworkPolicies) |
| HPA | 2 per env | api 2–6 at 70 % CPU; predicciones 1–4 at 75 % CPU. **Later task** |

### 4.3 Secret mapping

`secrets.mode` selects one of two ways to produce the single Kubernetes Secret `statline-secrets`. Its keys are the env var names.

| Mode | Used by | Behavior |
|---|---|---|
| `csi` | staging, prod | SecretProviderClass `statline-kv` (provider azure, `useVMManagedIdentity: "true"`, `usePodIdentity: "false"`) reads each Key Vault object in `secrets.csi.objects` (env var → KV name) and syncs it into the Secret. Pods that read secrets mount the CSI volume read-only at `/mnt/secrets-store`, which is what triggers the sync. Rotation: update KV, then restart the Deployment (section 8). |
| `plain` | k3d only | the chart renders the Secret from `secrets.plain.data`. Values are fake. With `devPostgres.enabled`, `DATABASE_URL` points to the dev Postgres. |

Per workload, the env vars it reads from the Secret (`<component>.secretKeys`, set via `secretKeyRef`):

| Workload | Secret keys |
|---|---|
| api (and its migrate initContainer) | `DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET` |
| predicciones | `DATABASE_URL` |
| ingesta CronJobs | `DATABASE_URL`, `API_SPORTS_KEY`, `BALLDONTLIE_API_KEY` (optional) |

Key Vault object names (`secrets.csi.objects`): staging uses `database-url-staging`, `jwt-secret-staging`, `jwt-refresh-secret-staging` and `api-sports-key`; prod uses the same names with `-prod`; `api-sports-key` and `balldontlie-api-key` are shared. The `balldontlie-api-key` object must exist in Key Vault even though the env var is optional: a missing object fails the CSI mount. Terraform outputs used for the SPC values: `key_vault_name`, `tenant_id`, `key_vault_csi_identity_client_id`. All names are configurable in values.

### 4.4 Redis

Own StatefulSet (1 replica, `redis:7.4-alpine`, uid 999, read-only root filesystem), with `--save ""`, `--appendonly no`, `maxmemory 128mb` and `allkeys-lru`. It is a cache, so `/data` is an emptyDir by default (`persistence.enabled` adds a PVC). Clients use `redis://redis.plataforma.svc.cluster.local:6379/<db>`: DB 0 for prod, DB 1 for staging, so the two environments never share keys (D-26). It has no auth, so its own NetworkPolicy (chart `gitops/charts/redis`) accepts port 6379 only from api pods in namespaces labelled `statline.io/ambiente` (Terraform sets the label on the statline namespaces; `make k3d-up` sets it locally). Redis gets no PodDisruptionBudget: it is one cache replica, and eviction costs only cache misses.

The api Deployment has an **initContainer** that runs `prisma migrate deploy` with the same image (`node_modules/.bin/prisma migrate deploy`), so the schema is migrated before the new version serves traffic.

### 4.5 Observability (SL-54)

Rendered only when `monitoring.enabled` is true (staging and prod; k3d is off because it has no Prometheus Operator CRDs). kube-prometheus-stack in `plataforma` (Terraform, `valores/kube-prometheus-stack.yaml`) runs Prometheus, Grafana and kube-state-metrics; `serviceMonitorSelectorNilUsesHelmValues` is `false`, so it picks up ServiceMonitors in every namespace.

| Object | Count per env | What |
|---|---|---|
| ServiceMonitor | 2 | `statline-api` and `statline-predicciones`: selects the Service, endpoint port `http` (named), path `/metrics`, interval `monitoring.interval` (30s). Extra labels: `monitoring.serviceMonitorLabels` |
| PrometheusRule | 1 | `<release>-alerts`, labelled `release: kube-prometheus-stack` (its `ruleSelectorNilUsesHelmValues` default selects by that label). Gated by `monitoring.alerts.enabled` |
| ConfigMap | 2 | `<release>-dashboard-api`, `<release>-dashboard-predicciones-ingesta`, from `gitops/charts/statline/dashboards/*.json` (`.Files.Get`), labelled `grafana_dashboard: "1"`. The Grafana sidecar watches all namespaces. Gated by `monitoring.dashboards.enabled` |

**Metrics the apps expose** (backend `services/*/src`, names confirmed in code):

| Source | Series | Labels |
|---|---|---|
| api | `statline_http_requests_total` | `method`, `route`, `status` |
| api | `statline_http_request_duration_seconds` (histogram) | `method`, `route` (no status) |
| predicciones | `statline_predicciones_requests_total` | `method`, `path`, `status` |
| predicciones | `statline_predicciones_request_seconds` (histogram) | `method`, `path` |

The api has no `statline_cache_requests_total` yet. The cache panels and nothing else depend on it; they show No data until the backend exposes it.

**Ingesta is not scraped.** Its CronJobs are short-lived and only the `serve` mode exposes metrics, which no Deployment runs. Its health comes from kube-state-metrics: `kube_job_status_failed` joined with `kube_job_owner` (owner kind `CronJob`, name `*-ingesta-*`) and `kube_cronjob_status_last_successful_time`.

**Alerts** (`PrometheusRule`; thresholds in `monitoring.alerts`):

| Alert | Expression (summary) | For | Severity |
|---|---|---|---|
| `StatLineApiHighErrorRatio` | api 5xx / all requests > `api5xxRatio` (0.05) | 10m | critical |
| `StatLineApiHighLatencyP95` | api p95 from the histogram > `apiP95Seconds` (1) | 10m | warning |
| `StatLinePrediccionesDown` | `up == 0` for the predicciones target | 5m | critical |
| `StatLineIngestaJobFailed` | a Job owned by an ingesta CronJob has failed | 0m | warning |
| `StatLineIngestaBasquetbolStale` | no successful `ingesta-basquetbol` run in `ingestaStaleHours` (36), or the CronJob never succeeded | 0m | warning |

**Dashboards** (Grafana, folder root; every dashboard has a `datasource` variable of type datasource and a `namespace` variable):

- `StatLine · API`: requests per second, 5xx ratio, p95 latency, cache hit ratio, request rate and 5xx ratio by route and status, p50/p95/p99, deployment replicas, HPA replicas (empty until SL-55), CPU as a share of request against the HPA target.
- `StatLine · Predicciones e ingesta`: predicciones request rate, 5xx ratio, p95 latency and target up, requests and latency by path, failed ingesta Jobs, CronJob last successful run and time since, failed Jobs by CronJob.

Dashboard uids are `statline-api-<env>` and `statline-pred-ingesta-<env>`, and the ConfigMap data keys start with the namespace, so staging and prod coexist in Grafana. Scraping `/metrics` is in-cluster only; the NetworkPolicy task (SL-55) must allow Prometheus to reach api and predicciones.

## 5. Contract with the backend images

Source of truth: backend `docs/ARCHITECTURE.md §8`. Summary:

| Image | Port | Probes | Env (ConfigMap) | Env (Secret) |
|---|---|---|---|---|
| `statline/api` | 3000 | `/healthz`, `/readyz` | `PORT`, `PREDICCIONES_URL`, `REDIS_URL`, `LOG_LEVEL`, `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL`, `CACHE_TTL_S` (60), `RATE_LIMIT_PER_MIN` (300), `RATE_LIMIT_LOGIN_PER_MIN` (10), `INGESTA_LANZADOR` (`deshabilitado`), `INGESTA_CRONJOB_PREFIJO` (`<release>-`, set by the chart) | `DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET` |
| `statline/predicciones` | 8000 | `/healthz`, `/readyz` | `ARTEFACTOS_DIR`, `LOG_LEVEL` | `DATABASE_URL` |
| `statline/ingesta` | 8080 (`serve`) | `/healthz`, `/readyz` | `TEMPORADA_BASQUETBOL`, `TEMPORADA_AMERICANO`, `TEMPORADA_FUTBOL`, `API_SPORTS_DAILY_QUOTA`, `THESPORTSDB_API_KEY` (3), `FALLBACK_HABILITADO` (`false`) | `DATABASE_URL`, `API_SPORTS_KEY`, `BALLDONTLIE_API_KEY` (optional) |
| `statline/web` | 8080 | `/healthz` | — | — |

`/readyz` of the api also checks Redis when `REDIS_URL` is set. The api trusts one proxy hop (ingress-nginx, `trust proxy` = 1). With `api.ingestaLanzador: kubernetes` the chart mounts the ServiceAccount token and renders a Role (`get` on `cronjobs`, `create` on `jobs`, group `batch`) and RoleBinding in the release namespace; otherwise none of that is rendered (D-30).

CronJob args: `["run", "basquetbol"]`, `["run", "americano"]`, `["run", "futbol"]`. Exit code ≠ 0 marks the Job failed. All images run as non-root and work with `readOnlyRootFilesystem` (ingesta and predicciones need an `emptyDir` on `/tmp`).

### 5.1 Network flows (NetworkPolicy matrix, SL-56)

Every pod in a release namespace starts with `default-deny` (ingress and egress). Each row below is an allow rule; "DNS" (UDP and TCP 53 to kube-system) is allowed for all pods. Ports are the container ports. Values keys are in `networkPolicies.*` (chart `values.yaml`).

| From → To | Port | Selector (values) | Why |
|---|---|---|---|
| ingress-nginx → web | 8080 | `ingressController` (plataforma, `app.kubernetes.io/name: ingress-nginx`) | public SPA traffic |
| ingress-nginx → api | 3000 | `ingressController` | `/api` traffic |
| Prometheus → api | 3000 | `prometheus` (plataforma, `app.kubernetes.io/name: prometheus`) | `/metrics`. NetworkPolicy filters by port, not path, so Prometheus reaches every api port |
| smoke pods → web, api | 8080, 3000 | label `statline.io/smoke: "true"` (`smokeTest.enabled`) | Argo CD PostSync smoke tests (SL-57) |
| extra peers → web, api | per rule | `extraIngressFrom` | hook for other branches |
| api → predicciones | 8000 | same namespace | forecasts |
| api → Redis | 6379 | `redis` (plataforma, `app.kubernetes.io/name: redis`) | cache |
| api → PostgreSQL | 5432 | `postgresCidr` (10.0.16.0/24, `snet-postgres`) | Prisma, readiness |
| api → Kubernetes API | `kubeApiPorts` (443, 6443) | `kubeApiCidr`, **required** when `api.ingestaLanzador: kubernetes` | on-demand ingestion Jobs (D-30) |
| predicciones ← api | 8000 | same namespace | forecasts |
| predicciones ← Prometheus | 8000 | `prometheus` | metrics |
| predicciones → PostgreSQL | 5432 | `postgresCidr` | models and data |
| ingesta → PostgreSQL | 5432 | `postgresCidr` | ingestion |
| ingesta → internet | 443 | `0.0.0.0/0` except 10/8, 172.16/12, 192.168/16 | API-Sports, balldontlie, TheSportsDB |
| api, predicciones, ingesta → dev Postgres | 5432 | pod labels (k3d only, `devPostgres.enabled`) | local database |
| Redis ← api | 6379 | namespace label `statline.io/ambiente` AND `app.kubernetes.io/name: statline-api` (redis chart) | cache; egress from Redis is denied |

Nothing else is allowed: web has no egress beyond DNS, ingesta has no ingress, and no pod reaches another namespace except the plataforma peers above.

## 6. CI/CD and GitOps

1. **CI (`ci.yml`, every repo, every push and PR):** lint and types; unit tests with a 70 % coverage gate (Vitest, Jest + Supertest, pytest); integration tests against an ephemeral PostgreSQL; multi-stage image builds; **Trivy** fails on HIGH/CRITICAL. Infra: `terraform fmt/validate`, `tflint`, `terraform plan` posted as a PR comment, and `helm lint --strict` plus `kubeconform` for the chart.
2. **Quality gate:** `develop` and `main` are protected: CI must pass and one reviewer must approve.
3. **Artifacts (app repos, `cd.yml`):** on push to `develop` or `main`, and on `vX.Y.Z` tags, each app repo pushes `statline/<image>:<short-sha>` (and `vX.Y.Z` on tags) to Docker Hub, builds it locally, scans it with Trivy before pushing, then sends `repository_dispatch` `bump-image` to this repo. `develop` → staging, `main` and tags → prod.
4. **Tag bump (`cd.yml` here):** validates the request (source repo allowlist, env, image, tag format), sets `<image>.image.tag` in `gitops/charts/statline/values-<env>.yaml` with `scripts/bump-image-tags.sh` (awk, keeps the file layout) and runs `helm lint --strict` on that values file. The commit goes onto a rolling branch, `gitops/bump-staging` or `gitops/bump-prod`, rebased on its target and pushed with a lease (retried when a branch moved). The workflow then opens or updates the PR into `develop` or `main`, using the `GITOPS_PR_TOKEN` secret so CI runs on it. `auto-merge.yml` merges staging bump PRs when CI passes; prod bump PRs are reviewed by hand (D-36). Manual runs: `workflow_dispatch` with env, image and tag.
5. **GitOps sync:** Argo CD watches `gitops/` and syncs `statline-staging` (from `develop`) and `statline-prod` (from `main`).
6. **Verify (SL-57):** a PostSync hook Job (`<release>-smoke`, D-33) checks `/healthz` of web and `/healthz` + `/readyz` of api and predicciones, from inside the namespace. A failed check fails the sync. **Argo CD does not roll back**: the new pods keep running. Rollback is a `git revert` of the image-tag bump (D-34). See `docs/RUNBOOK.md`.

## 7. Branch strategy

- **Permanent:** `main` (production, `statline-prod`) and `develop` (staging, `statline-staging`, default branch). Both protected: no direct pushes, no force pushes, PR + green CI + 1 approval.
- **Temporary:** `feature/<issue>-<desc>` and `fix/<issue>-<desc>` from `develop`, back into `develop` (**squash merge**). `release/vX.Y.Z` from `develop` into `main` (**merge commit**) and back-merged into `develop`. `hotfix/vX.Y.Z` from `main` into `main` and `develop`. **Bot:** `gitops/bump-staging` and `gitops/bump-prod`, written only by `cd.yml` (D-36); don't push to them by hand.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `ci:`). **Versions:** SemVer tags `vX.Y.Z` on `main`. **Traceability:** every PR says `Closes #N`; merged branches are deleted automatically.

## 8. Operations

| Task | How |
|---|---|
| First deploy | `make bootstrap` → `make apply-aks` → `make plan` → `make apply` → `az aks get-credentials` (D-24) |
| Daily stop | `make destroy` (data is lost unless dumped: `pg_dump` through a client pod first) |
| DB shell | `kubectl run psql --rm -it --image=postgres:16-alpine -- psql "$DATABASE_URL"` |
| Rotate a secret | update it in Key Vault; the CSI driver re-syncs within 5 min; restart the Deployment |
| Local cluster | `make k3d-up`, then `make k3d-deploy` (Redis and the chart with `values-k3d.yaml`); the README in `gitops/` has the full steps |
