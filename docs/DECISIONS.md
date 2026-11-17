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
| D-16 | 2026-11-16 | Platform Helm releases are four (ingress-nginx, cert-manager, Argo CD, kube-prometheus-stack). Redis is our own StatefulSet in the GitOps chart, not a Bitnami release (proposal said five) | Decided |
| D-17 | 2026-11-16 | The domain is decided at deploy time (`dominio`, default null). The `dns` module exists only when it is set | Decided |
| D-18 | 2026-11-16 | cert-manager ClusterIssuers live in `gitops/` and are applied by Argo CD, not by `kubernetes_manifest` in Terraform (which needs a live cluster at plan time) | Decided |
| D-19 | 2026-11-16 | Ingress public IP is a static Standard `azurerm_public_ip` in `rg-statline`, used by ingress-nginx through Azure annotations; the AKS identity gets Network Contributor on that resource group | Decided |
| D-20 | 2026-11-16 | `kubernetes` (~> 2.33) and `helm` (~> 2.16) providers configured from `module.aks.kube_config` in the same stack; first apply creates the cluster alone (`make apply-aks`) | Decided |
| D-21 | 2026-11-16 | Platform charts pinned: ingress-nginx 4.15.1, cert-manager v1.21.3, argo-cd 10.11.6, kube-prometheus-stack 92.16.0 (all released at least two weeks before the decision) | Decided |

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

### D-12 · Migrations in an initContainer
`prisma migrate deploy` is idempotent and takes an advisory lock, so two replicas starting together don't race. Rolling back an image does **not** roll back the schema; migrations must be backward compatible (expand, then contract).

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

## 4. Future work

- Separate `statline-gitops` repo if more teams deploy (see D-10).
- Azure Database for PostgreSQL read replica and zone redundancy (not available on Burstable).
- Workload identity per Deployment instead of the shared CSI add-on identity.
- Spot node pool for the CronJobs.
- Argo CD behind an Ingress with TLS (currently port-forward only, D-21).
- Persistent Prometheus and Grafana storage (currently emptyDir / none, D-21).
