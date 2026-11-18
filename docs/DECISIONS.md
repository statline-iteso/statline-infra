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
| D-13 | 2026-11-16 | k3d (k3s 1.30) for local clusters, Traefik disabled in favor of ingress-nginx | Decided |
| D-14 | 2026-11-16 | Docs in English; course-delivery sections and domain names in Spanish | Decided |
| D-15 | 2026-11-16 | `develop` is the default branch; `main` only receives `release/*` and `hotfix/*` | Decided |
| D-16 | 2026-11-16 | One database per environment (`statline_staging`, `statline_prod`) on the same PostgreSQL server; apps use the admin login | Decided |
| D-17 | 2026-11-16 | Secrets per environment (`database-url-<env>`, `jwt-*-<env>`); one shared `api-sports-key`, placeholder set out of band | Decided |
| D-18 | 2026-11-16 | Key Vault with Azure RBAC, Standard SKU, 7-day soft delete, purge protection off, public endpoint with default Allow | Decided |
| D-16 | 2026-11-16 | Log Analytics with a 0.5 GB/day cap; AKS diagnostics without `kube-audit` (cheap category list) | Decided |

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

### D-12 · Migrations in an initContainer
`prisma migrate deploy` is idempotent and takes an advisory lock, so two replicas starting together don't race. Rolling back an image does **not** roll back the schema; migrations must be backward compatible (expand, then contract).

### D-16 · Log Analytics with a daily cap and cheap AKS categories
Log Analytics (`log-statline`, PerGB2018) bills per GB ingested, with no fixed monthly fee. Two guards keep the student credit safe:
- **Daily cap** `daily_quota_gb = 0.5` (variable `log_analytics_daily_quota_gb`, must be > 0). Ingestion stops when the cap is reached, so a noisy resource cannot run up the bill. **Trade-off:** logs after the cap are lost for the rest of the day, and the Azure cap-reached alert is not configured yet.
- **AKS without `kube-audit`** (and without `kube-audit-admin`, `csi-*`, `cloud-controller-manager`). `kube-audit` logs every API request and is the largest category. The chosen set covers the control plane and autoscaler, which is what the course needs to debug. Metrics (AllMetrics) are still sent.

Cost (estimate, check the Azure price calculator for the region): pay-as-you-go is roughly USD 2–3 per GB ingested (East US), with a small free allowance. At the cap, worst case is 0.5 GB/day × 30 ≈ 15 GB/month ≈ USD 35/month. The expected volume with these categories is far lower. Retention 30 days is the minimum for PerGB2018 and costs nothing extra up to that point.

**Why not allLogs everywhere:** kube-audit and csi logs would hit the cap in hours and hide the rest. PostgreSQL uses allLogs because its volume is low on a B1ms server.

**Dependency:** the workspace has no inputs from other modules, so aks (`oms_agent`) can take its id while observabilidad takes the aks and datos ids for diagnostics. No cycle (checked with `terraform graph`).

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
