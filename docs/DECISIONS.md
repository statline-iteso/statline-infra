# Decisions, Limitations and Future Work

What we decided, why, what we gave up, and what we'd do with more time or budget. Add a new entry whenever something is decided or changed; don't rewrite history. If a decision is replaced, mark it **Superseded by D-xx**.

**Status values:** **Decided** (settled) · **Proposed** (preferred, needs the other owner) · **Superseded**.

## 1. Decision log

| ID | Date | Decision | Status |
|---|---|---|---|
| D-01 | 2026-11-16 | Three repos: infra, backend (api + ingesta + predicciones), frontend | Decided |
| D-02 | 2026-11-16 | Azure (Azure for Students) + AKS + Terraform | Decided |
| D-03 | 2026-11-16 | One AKS cluster with `statline-staging` and `statline-prod` namespaces | Decided |
| D-04 | 2026-11-16 | Terraform state in Azure Storage with Entra ID auth (no account keys) | Decided |
| D-05 | 2026-11-16 | Plain `azurerm` resources in local modules; no registry modules | Decided |
| D-06 | 2026-11-16 | PostgreSQL with private access only; firewall rules replaced by the delegated subnet | Decided |
| D-07 | 2026-11-16 | Burstable SKUs: nodes Standard_B2s (2→4), PostgreSQL B_Standard_B1ms, AKS Free tier | Decided (forced by budget) |
| D-08 | 2026-11-16 | Azure CNI + Azure network policy (NetworkPolicy enforced without Calico) | Decided |
| D-09 | 2026-11-16 | Secrets: Key Vault + Secrets Store CSI add-on, synced to one Kubernetes Secret per env | Decided |
| D-10 | 2026-11-16 | GitOps manifests live in this repo under `gitops/` (the "GitOps repository" of the proposal) | Decided |
| D-11 | 2026-11-16 | Images on Docker Hub (`statline/*`), tags = short SHA, plus `vX.Y.Z` on releases | Decided |
| D-12 | 2026-11-16 | Prisma migrations run in an initContainer of the api Deployment | Decided |
| D-16 | 2026-11-16 | Redis as our own StatefulSet chart (`gitops/charts/redis`), not Bitnami | Decided |
| D-17 | 2026-11-16 | `secrets.mode`: `csi` for staging and prod, `plain` only for k3d | Decided |
| D-18 | 2026-11-16 | Dev PostgreSQL inside the cluster, only with `values-k3d.yaml` | Decided |
| D-19 | 2026-11-16 | Chart at `gitops/charts/statline` (not `gitops/chart`); app label scheme with the component in `app.kubernetes.io/name` | Decided |
| D-20 | 2026-11-16 | Backend contract knobs as chart values; on-demand ingestion RBAC only when `api.ingestaLanzador: kubernetes`; fallback ingestion off in staging and prod | Decided |
| D-13 | 2026-11-16 | k3d (k3s 1.30) for local clusters, Traefik disabled in favor of ingress-nginx | Decided |
| D-14 | 2026-11-16 | Docs in English; course-delivery sections and domain names in Spanish | Decided |
| D-15 | 2026-11-16 | `develop` is the default branch; `main` only receives `release/*` and `hotfix/*` | Decided |
| D-16 | 2026-11-16 | One database per environment (`statline_staging`, `statline_prod`) on the same PostgreSQL server; apps use the admin login | Decided |
| D-17 | 2026-11-16 | Secrets per environment (`database-url-<env>`, `jwt-*-<env>`); one shared `api-sports-key`, placeholder set out of band | Decided |
| D-18 | 2026-11-16 | Key Vault with Azure RBAC, Standard SKU, 7-day soft delete, purge protection off, public endpoint with default Allow | Decided |
| D-16 | 2026-11-16 | Log Analytics with a 0.5 GB/day cap; AKS diagnostics without `kube-audit` (cheap category list) | Decided |
| D-16 | 2026-11-16 | Platform Helm releases are four (ingress-nginx, cert-manager, Argo CD, kube-prometheus-stack). Redis is our own StatefulSet in the GitOps chart, not a Bitnami release (proposal said five) | Decided |
| D-17 | 2026-11-16 | The domain is decided at deploy time (`dominio`, default null). The `dns` module exists only when it is set | Decided |
| D-18 | 2026-11-16 | cert-manager ClusterIssuers live in `gitops/` and are applied by Argo CD, not by `kubernetes_manifest` in Terraform (which needs a live cluster at plan time) | Decided |
| D-19 | 2026-11-16 | Ingress public IP is a static Standard `azurerm_public_ip` in `rg-statline`, used by ingress-nginx through Azure annotations; the AKS identity gets Network Contributor on that resource group | Decided |
| D-20 | 2026-11-16 | `kubernetes` (~> 2.33) and `helm` (~> 2.16) providers configured from `module.aks.kube_config` in the same stack; first apply creates the cluster alone (`make apply-aks`) | Decided |
| D-21 | 2026-11-16 | Platform charts pinned: ingress-nginx 4.15.1, cert-manager v1.21.3, argo-cd 10.11.6, kube-prometheus-stack 92.16.0 (all released at least two weeks before the decision) | Decided |

## 2. Details

### D-03 · One cluster, two namespaces, two databases
Two clusters would double the node cost, which the student credit can't cover. Namespaces plus NetworkPolicies and separate databases (`statline_staging`, `statline_prod`, see D-16) on one PostgreSQL server give enough isolation for a course project. **Trade-off:** a bad platform-chart upgrade or a PostgreSQL outage affects both environments.

### D-04 · State with Entra ID
`use_azuread_auth = true` and `shared_access_key_enabled = false` on the storage account: nobody handles storage keys, and access is the *Storage Blob Data Contributor* role. Locking uses the blob lease, which the azurerm backend does by default.

### D-06 · Private PostgreSQL
The proposal lists "reglas de firewall". With a delegated subnet and `public_network_access_enabled = false` the server has no public endpoint at all, which is stricter. Human access goes through a client pod inside the cluster.

### D-07 · Burstable SKUs
Standard_B2s (2 vCPU, 4 GiB) is the smallest size that fits the platform charts plus our workloads on 2 nodes. B-series CPU credits can run out under sustained load; the HPA limits (api ≤ 6, predicciones ≤ 4) and the 4-node cap keep it bounded.

### D-10 · GitOps folder instead of a fourth repo
The proposal says `cd.yml` updates "el repositorio GitOps". Keeping `gitops/` in this repo means infra changes and their manifests are reviewed together, and the app repos only need permission to dispatch an event here. **If** the team prefers a separate `statline-gitops` repo, only the Argo CD `repoURL` and the dispatch target change.

### D-16 · One database per environment, admin login for apps
`modules/datos` creates `statline_staging` and `statline_prod` on the same server (`for_each` over `bases_de_datos`, both `prevent_destroy`). Output `database_urls` is a sensitive map keyed by env, and each URL uses `sslmode=require`. The former single `statline` database was replaced before anything was applied (Azure was never provisioned), so there is no state to migrate.

The apps connect with the server administrator login. **Limitation:** the same superuser credentials reach both databases, so an app bug in staging could read prod. Per-app roles with least privilege would need the `postgresql` provider (roles and grants managed by Terraform) and are left as future work. Prisma needs DDL rights for its migrations, which is another reason to keep the admin login for now.

### D-17 · Secrets per environment
`database-url-<env>`, `jwt-secret-<env>` and `jwt-refresh-secret-<env>` are generated per environment, so a staging token can never validate in prod. `random_password` (64 chars, alphanumeric so they are safe in URLs and env files) generates the JWT values; they are kept in the Terraform state, which is in the Entra-authenticated storage account (D-04). `api-sports-key` is one secret because the API-Sports quota belongs to the account, not to an environment. Its placeholder value is set once in the portal or with `az keyvault secret set`, and `ignore_changes = [value]` stops Terraform from overwriting it.

### D-18 · Key Vault settings
- **RBAC, not access policies.** The deployer gets *Key Vault Secrets Officer* so Terraform can write the secrets; the CSI add-on identity gets *Key Vault Secrets User* (read only).
- **Purge protection off, soft delete 7 days (the minimum).** Students run `make destroy` often and re-create the stack. With purge protection on, the vault name stays reserved for the retention period and the vault cannot be purged. The name carries a random suffix, so a re-created stack never collides with a soft-deleted vault. **Trade-off:** a deleted vault cannot be recovered after 7 days, so an accidental destroy of the vault is not undoable later. Acceptable for a course project, where the secrets are regenerated or re-set anyway.
- **Public endpoint, default Allow.** The CSI driver in AKS reads the vault over its public endpoint. Private endpoints and a private DNS zone would add cost and wiring that the Azure for Students budget does not cover. Access is still limited by RBAC and by the lack of any access keys.
- **Known first-apply behaviour:** a new role assignment can take a few minutes to propagate, so the first apply may fail with 403 on the secret writes. Running `make apply` again resolves it.
### D-16 · Redis StatefulSet instead of Bitnami
The Bitnami chart brings a large default values surface, replication and sentinel options, and metrics sidecars that a single-replica cache does not need. Our chart is one StatefulSet, one Service and a pinned `redis:7.4-alpine` with a read-only root filesystem and non-root uid 999. It runs as a cache (`--save ""`, `--appendonly no`, `maxmemory 128mb allkeys-lru`) on an emptyDir, so a restart costs cache misses only. Index 0 is prod and 1 is staging. **Trade-off:** no auth and no replication. NetworkPolicies must restrict port 6379. Bitnami stays an option if the cache ever needs HA.

### D-17 · `secrets.mode`: csi or plain
Staging and prod always read Key Vault through the Secrets Store CSI driver (D-09): the Secret is a sync product, never written by hand or by the chart. `plain` renders the same Secret name from values, but only for k3d, where there is no Key Vault. The chart rejects any other mode. Every workload that reads secrets mounts the CSI volume, because the Secret is synced only while a pod mounts it. The Key Vault object names are values (`secrets.csi.objects`), so renaming them does not touch the templates.

### D-18 · Dev PostgreSQL in k3d only
`devPostgres.enabled` renders an ephemeral `postgres:16-alpine` (emptyDir, fake password) in the release namespace, so the api can run its migrations locally. It is off in staging and prod, where the database is Azure Database for PostgreSQL behind the private endpoint (D-06).

### D-19 · Chart location and labels
The chart lives at `gitops/charts/statline` so the Redis chart can sit beside it. CONVENTIONS section 2 said `gitops/chart/`; that text is updated in the same PR. Selectors must use only `app.kubernetes.io/name` (AGENTS.md section 7), so the name carries the component (`statline-api`) and the release is in `app.kubernetes.io/instance`. **Trade-off:** the name label is not the chart name, which is unusual but needed for unique selectors.

### D-20 · Backend contract knobs and ingestion launcher
`CACHE_TTL_S`, `RATE_LIMIT_PER_MIN`, `RATE_LIMIT_LOGIN_PER_MIN`, `INGESTA_LANZADOR`, `THESPORTSDB_API_KEY` and `FALLBACK_HABILITADO` are ConfigMap values; `BALLDONTLIE_API_KEY` is an optional Secret key. The api ServiceAccount token and a namespaced Role/RoleBinding (`get` cronjobs, `create` jobs) are rendered only when `api.ingestaLanzador: kubernetes`, so the default pod has no API server access. `FALLBACK_HABILITADO` is `"false"` in staging and prod because fallback data can duplicate games. The api migrate initContainer keeps `secretKeyRef` for `DATABASE_URL`: the pod mounts the CSI volume, volumes are mounted before container env is resolved, so the synced Secret exists in time. **Trade-off:** the first pod after a fresh install may show a short `CreateContainerConfigError` while the driver syncs.

### D-12 · Migrations in an initContainer
`prisma migrate deploy` is idempotent and takes an advisory lock, so two replicas starting together don't race. Rolling back an image does **not** roll back the schema; migrations must be backward compatible (expand, then contract).

### D-16 · Log Analytics with a daily cap and cheap AKS categories
Log Analytics (`log-statline`, PerGB2018) bills per GB ingested, with no fixed monthly fee. Two guards keep the student credit safe:
- **Daily cap** `daily_quota_gb = 0.5` (variable `log_analytics_daily_quota_gb`, must be > 0). Ingestion stops when the cap is reached, so a noisy resource cannot run up the bill. **Trade-off:** logs after the cap are lost for the rest of the day, and the Azure cap-reached alert is not configured yet.
- **AKS without `kube-audit`** (and without `kube-audit-admin`, `csi-*`, `cloud-controller-manager`). `kube-audit` logs every API request and is the largest category. The chosen set covers the control plane and autoscaler, which is what the course needs to debug. Metrics (AllMetrics) are still sent.

Cost (estimate, check the Azure price calculator for the region): pay-as-you-go is roughly USD 2–3 per GB ingested (East US), with a small free allowance. At the cap, worst case is 0.5 GB/day × 30 ≈ 15 GB/month ≈ USD 35/month. The expected volume with these categories is far lower. Retention 30 days is the minimum for PerGB2018 and costs nothing extra up to that point.

**Why not allLogs everywhere:** kube-audit and csi logs would hit the cap in hours and hide the rest. PostgreSQL uses allLogs because its volume is low on a B1ms server.

**Dependency:** the workspace has no inputs from other modules, so aks (`oms_agent`) can take its id while observabilidad takes the aks and datos ids for diagnostics. No cycle (checked with `terraform graph`).
### D-16 · Four platform releases, Redis as our own StatefulSet
Bitnami discontinued its free images, so the Bitnami Redis chart is no longer a safe pin. Redis 7 runs as a StatefulSet in the GitOps chart (`gitops/`), which Argo CD syncs. That makes the platform list four `helm_release` instead of the proposal's five. Argo CD's own chart still starts a small internal Redis for its cache; that is Argo's, not StatLine's.

### D-17 · Domain at deploy time
`dominio` stays `null` until the team picks a domain. With `null`, the `dns` module is not created: no DNS zone is billed (about USD 0.50/month when it exists, plus queries). Staging and prod are served by the same ingress; the records are `@` (prod) and `staging`.

### D-18 · ClusterIssuers in GitOps
A `kubernetes_manifest` needs the CRDs and a reachable cluster at plan time, which breaks the first `make plan`. The Let's Encrypt issuers are plain YAML in `gitops/`, applied by Argo CD after cert-manager is up.

### D-19 · Public IP outside the node resource group
The IP is in `rg-statline`, so Terraform owns it and the DNS record refers to it. The load balancer lives in the `MC_` group and reads the IP through `azure-load-balancer-resource-group` and `azure-pip-name`. Network Contributor on the whole resource group is broader than the single IP, but it is the scope AKS documents for a BYO IP in another group. **Trade-off:** the identity can also write the VNet and NSG in that group.

### D-20 · Providers from the cluster in the same stack
The providers read `module.aks.kube_config`, so on a first run the host is unknown at plan time. The first apply therefore creates AKS alone (`make apply-aks`, which targets `module.aks`), then `make plan` / `make apply` create the rest. Every later run is a normal plan. `kube_config` is the local-account kubeconfig of the cluster (not Entra ID); it is sensitive and never written to a file. **Destroy order** relies on Terraform's provider dependencies; verify on the first `make destroy` before relying on it.

### D-21 · Chart versions and trimmed values
Versions are pinned in `terraform/modules/plataforma/variables.tf`. Values, in `terraform/modules/plataforma/valores/`:
- **kube-prometheus-stack:** Prometheus 3-day retention on emptyDir (no PVC), Alertmanager off, unexposed AKS components off, Grafana without persistence, ServiceMonitor selectors that pick up every namespace. Grafana's admin password comes from `random_password`; read it with `terraform output -raw grafana_admin_password`.
- **ingress-nginx:** one replica, metrics and ServiceMonitor on (depends on kube-prometheus-stack), the static IP through the Azure annotations and `/healthz` as the health probe path.
- **cert-manager:** CRDs installed by the chart, ServiceMonitor on.
- **Argo CD:** one replica of each component, no Dex, no notifications, no HA Redis, `server.insecure` with no Ingress. Access by port-forward: `kubectl -n plataforma port-forward svc/argo-cd-argocd-server 8080:80`. **Limitation:** the UI is not public yet; an Ingress with TLS comes with the GitOps work (SL-53).

## 3. Known limitations

- **AKS 1.30** is what the proposal specifies. Check `az aks get-versions -l <region>` before the first apply: if 1.30 is no longer offered in standard support, use the oldest available minor and record it here.
- `make destroy` deletes the database. Until backups to a storage account exist, dump before destroying.
- The `plan` job in CI is skipped until the Azure OIDC app registration and the repo secrets exist (docs/pendientes.md).
- No WAF, no private AKS API server (cost and complexity).
- Apps use the PostgreSQL admin login for both environments (D-16); per-app roles need the `postgresql` provider.
- Key Vault has a public endpoint (D-18); private endpoints are out of budget scope.

## 4. Future work

- Separate `statline-gitops` repo if more teams deploy (see D-10).
- Azure Database for PostgreSQL read replica and zone redundancy (not available on Burstable).
- Workload identity per Deployment instead of the shared CSI add-on identity.
- Spot node pool for the CronJobs.
- Argo CD behind an Ingress with TLS (currently port-forward only, D-21).
- Persistent Prometheus and Grafana storage (currently emptyDir / none, D-21).
