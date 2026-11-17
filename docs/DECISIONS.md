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
| D-13 | 2026-11-16 | k3d (k3s 1.30) for local clusters, Traefik disabled in favor of ingress-nginx | Decided |
| D-14 | 2026-11-16 | Docs in English; course-delivery sections and domain names in Spanish | Decided |
| D-15 | 2026-11-16 | `develop` is the default branch; `main` only receives `release/*` and `hotfix/*` | Decided |

## 2. Details

### D-03 · One cluster, two namespaces
Two clusters would double the node cost, which the student credit can't cover. Namespaces plus NetworkPolicies and separate databases give enough isolation for a course project. **Trade-off:** a bad platform-chart upgrade affects both environments.

### D-04 · State with Entra ID
`use_azuread_auth = true` and `shared_access_key_enabled = false` on the storage account: nobody handles storage keys, and access is the *Storage Blob Data Contributor* role. Locking uses the blob lease, which the azurerm backend does by default.

### D-06 · Private PostgreSQL
The proposal lists "reglas de firewall". With a delegated subnet and `public_network_access_enabled = false` the server has no public endpoint at all, which is stricter. Human access goes through a client pod inside the cluster.

### D-07 · Burstable SKUs
Standard_B2s (2 vCPU, 4 GiB) is the smallest size that fits the platform charts plus our workloads on 2 nodes. B-series CPU credits can run out under sustained load; the HPA limits (api ≤ 6, predicciones ≤ 4) and the 4-node cap keep it bounded.

### D-10 · GitOps folder instead of a fourth repo
The proposal says `cd.yml` updates "el repositorio GitOps". Keeping `gitops/` in this repo means infra changes and their manifests are reviewed together, and the app repos only need permission to dispatch an event here. **If** the team prefers a separate `statline-gitops` repo, only the Argo CD `repoURL` and the dispatch target change.

### D-16 · Redis StatefulSet instead of Bitnami
The Bitnami chart brings a large default values surface, replication and sentinel options, and metrics sidecars that a single-replica cache does not need. Our chart is one StatefulSet, one Service and a pinned `redis:7.4-alpine` with a read-only root filesystem and non-root uid 999. It runs as a cache (`--save ""`, `--appendonly no`, `maxmemory 128mb allkeys-lru`) on an emptyDir, so a restart costs cache misses only. Index 0 is prod and 1 is staging. **Trade-off:** no auth and no replication. NetworkPolicies must restrict port 6379. Bitnami stays an option if the cache ever needs HA.

### D-17 · `secrets.mode`: csi or plain
Staging and prod always read Key Vault through the Secrets Store CSI driver (D-09): the Secret is a sync product, never written by hand or by the chart. `plain` renders the same Secret name from values, but only for k3d, where there is no Key Vault. The chart rejects any other mode. Every workload that reads secrets mounts the CSI volume, because the Secret is synced only while a pod mounts it. The Key Vault object names are values (`secrets.csi.objects`), so renaming them does not touch the templates.

### D-18 · Dev PostgreSQL in k3d only
`devPostgres.enabled` renders an ephemeral `postgres:16-alpine` (emptyDir, fake password) in the release namespace, so the api can run its migrations locally. It is off in staging and prod, where the database is Azure Database for PostgreSQL behind the private endpoint (D-06).

### D-19 · Chart location and labels
The chart lives at `gitops/charts/statline` so the Redis chart can sit beside it. CONVENTIONS section 2 said `gitops/chart/`; that text is updated in the same PR. Selectors must use only `app.kubernetes.io/name` (AGENTS.md section 7), so the name carries the component (`statline-api`) and the release is in `app.kubernetes.io/instance`. **Trade-off:** the name label is not the chart name, which is unusual but needed for unique selectors.

### D-12 · Migrations in an initContainer
`prisma migrate deploy` is idempotent and takes an advisory lock, so two replicas starting together don't race. Rolling back an image does **not** roll back the schema; migrations must be backward compatible (expand, then contract).

## 3. Known limitations

- **AKS 1.30** is what the proposal specifies. Check `az aks get-versions -l <region>` before the first apply: if 1.30 is no longer offered in standard support, use the oldest available minor and record it here.
- `make destroy` deletes the database. Until backups to a storage account exist, dump before destroying.
- The `plan` job in CI is skipped until the Azure OIDC app registration and the repo secrets exist (docs/pendientes.md).
- No WAF, no private AKS API server (cost and complexity).

## 4. Future work

- Separate `statline-gitops` repo if more teams deploy (see D-10).
- Azure Database for PostgreSQL read replica and zone redundancy (not available on Burstable).
- Workload identity per Deployment instead of the shared CSI add-on identity.
- Spot node pool for the CronJobs.
