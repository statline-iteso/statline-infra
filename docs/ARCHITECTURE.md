# Infra Architecture

What runs where, how it gets there, and the contracts with the backend and frontend repos. Items marked **(planned)** are designed but not built yet; each one names its issue.

## 1. Overview

```
                Internet
                   │ 80/443
         ┌─────────▼──────────┐  (planned SL-12)  public IP + DNS A record
         │   ingress-nginx    │  TLS from cert-manager (Let's Encrypt)
         └───┬───────────┬────┘
   /         │           │  /api
   ┌─────────▼──┐   ┌────▼──────┐     ┌──────────────┐
   │ web (2)    │   │ api (2–6) │────▶│ predicciones │ (1–4)
   │ nginx SPA  │   │ Node 20   │     │ FastAPI      │
   └────────────┘   └──┬─────┬──┘     └──────┬───────┘
                       │     │ Redis (planned SL-31)
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
| `datos` | done | `psql-statline-<5>` PostgreSQL 16 `B_Standard_B1ms`, 32 GiB auto-grow, 7-day backups, private access only, `require_secure_transport=on` · database `statline` (`prevent_destroy`) · admin password from `random_password` |
| `seguridad` | planned (SL-09) | `kv-statline-<5>` (RBAC, purge protection, network ACLs) · secrets `database-url-<env>`, `jwt-secret-<env>`, `jwt-refresh-secret-<env>` (`staging`, `prod`), `api-sports-key`, `balldontlie-api-key` · *Key Vault Secrets User* for the CSI add-on identity |
| `observabilidad` | planned (SL-10) | `log-statline` (30 days) · `diagnostic_settings` for AKS, PostgreSQL, Key Vault · AKS `oms_agent` |
| `dns` | planned (SL-12) | `dns_zone` · `public_ip` for the ingress (in the node resource group) · A record |
| `plataforma` | planned (SL-12) | `helm_release`: ingress-nginx, cert-manager, argo-cd, kube-prometheus-stack — all in `plataforma`. Redis is **not** here: it is deployed by Argo CD from `gitops/charts/redis` (D-16) |

Outputs other repos or the chart rely on: `aks_cluster_name`, `resource_group_name`, `key_vault_csi_identity_client_id`, `postgres_fqdn`, `database_url` (sensitive). Renaming one is a contract change.

### Why private access for PostgreSQL

With a delegated subnet the server has no public endpoint, so the proposal's "firewall rules" are replaced by the network boundary: only the VNet (AKS pods) can reach it. Admin access for humans goes through `kubectl run` with a `postgres:16` client pod or `kubectl port-forward` to a pod (D-06).

## 4. Cluster layout (SL-53 chart, SL-58 values; HPA, NetworkPolicy and PDB are later tasks)

### 4.1 Chart layout

| Path | What |
|---|---|
| `gitops/charts/statline/` | the environment chart (`Chart.yaml` v2, 0.1.0). Templates: `_helpers.tpl`, `web.yaml`, `api.yaml`, `predicciones.yaml`, `ingesta.yaml` (ServiceAccount, ConfigMap, 3 CronJobs), `ingress.yaml`, `secrets.yaml`, `dev-postgres.yaml` (k3d only) |
| `gitops/charts/statline/values.yaml` | documented defaults. Not renderable alone: image tags are required |
| `gitops/charts/statline/values-{staging,prod,k3d}.yaml` | one file per environment. Argo CD renders staging and prod; `make k3d-deploy` renders k3d |
| `gitops/charts/redis/` | Redis StatefulSet, Service and ServiceAccount for `plataforma` (D-16) |
| `gitops/argocd/` | `project.yaml` (AppProject `statline`), `root.yaml` (app of apps), `apps/` (statline-staging, statline-prod, redis, plataforma-config) |
| `gitops/plataforma/` | cert-manager `ClusterIssuer`s `letsencrypt-staging` and `letsencrypt-prod` |

Image tags live on `<component>.image.tag` (`web`, `api`, `predicciones`, `ingesta`). The image is `<global.imageRegistry>/<image.repository>:<tag>`, so `docker.io/statline/api:<tag>`. `cd.yml` is the only writer of those paths in `values-staging.yaml` and `values-prod.yaml`.

Naming and labels: objects are named `<release>-<component>` (release `statline-staging` gives `statline-staging-api`), and the CronJobs `<release>-ingesta-<job>`. `app.kubernetes.io/name` is `statline-<component>` so selectors use that label alone (AGENTS.md section 7). Every object also carries `app.kubernetes.io/{instance,part-of,component,version,managed-by}` and `statline.io/environment`.

### 4.2 Objects per environment

| Object | Count | Detail |
|---|---|---|
| Namespace | 3 | `plataforma`, `statline-staging`, `statline-prod` (created by `k3d-up` or ops; Argo uses `CreateNamespace=false`) |
| Deployment | 3 per env | `web` (2 replicas), `api` (2, initContainer `migrate`), `predicciones` (1) |
| StatefulSet | 1 | Redis, in `plataforma` (`gitops/charts/redis`) |
| CronJob | 3 per env | `ingesta-basquetbol` `0 8 * * *` · `ingesta-americano` `0 8 * * 2` · `ingesta-futbol` `0 8 * * 1,5` (UTC). `concurrencyPolicy: Forbid`, `backoffLimit: 1`, `activeDeadlineSeconds: 3600` |
| Service | 4 | ClusterIP for web, api and predicciones (port 80 to the container port) and `redis` (6379) |
| Ingress | 1 per env | `/api` → api, `/` → web; class `nginx`; TLS through cert-manager when `ingress.tls.enabled` |
| ServiceAccount | 1 per workload | `automountServiceAccountToken: false` (a values switch per component) |
| ConfigMap | 1 for api, predicciones, ingesta | non-secret settings. Web has no env, so it has no ConfigMap. Changes roll the pods through a `checksum/config` annotation |
| SecretProviderClass or Secret | 1 per env | see 4.3 |
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

Own StatefulSet (1 replica, `redis:7.4-alpine`, uid 999, read-only root filesystem), with `--save ""`, `--appendonly no`, `maxmemory 128mb` and `allkeys-lru`. It is a cache, so `/data` is an emptyDir by default (`persistence.enabled` adds a PVC). Clients use `redis://redis.plataforma.svc.cluster.local:6379/<db>`: DB 0 for prod, DB 1 for staging, so the two environments never share keys (D-16). It has no auth: NetworkPolicies (later task) must limit who reaches port 6379.
| NetworkPolicy | per env | `default-deny-ingress` + allow ingress-nginx → web/api, api → predicciones, Prometheus → `/metrics` |
| PodDisruptionBudget | per env | `minAvailable: 1` for web and api |

The api Deployment has an **initContainer** that runs `prisma migrate deploy` with the same image (`node_modules/.bin/prisma migrate deploy`), so the schema is migrated before the new version serves traffic.

## 5. Contract with the backend images

Source of truth: backend `docs/ARCHITECTURE.md §8`. Summary:

| Image | Port | Probes | Env (ConfigMap) | Env (Secret) |
|---|---|---|---|---|
| `statline/api` | 3000 | `/healthz`, `/readyz` | `PORT`, `PREDICCIONES_URL`, `REDIS_URL`, `LOG_LEVEL`, `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL`, `CACHE_TTL_S` (60), `RATE_LIMIT_PER_MIN` (300), `RATE_LIMIT_LOGIN_PER_MIN` (10), `INGESTA_LANZADOR` (`deshabilitado`) | `DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET` |
| `statline/predicciones` | 8000 | `/healthz`, `/readyz` | `ARTEFACTOS_DIR`, `LOG_LEVEL` | `DATABASE_URL` |
| `statline/ingesta` | 8080 (`serve`) | `/healthz`, `/readyz` | `TEMPORADA_BASQUETBOL`, `TEMPORADA_AMERICANO`, `TEMPORADA_FUTBOL`, `API_SPORTS_DAILY_QUOTA`, `THESPORTSDB_API_KEY` (3), `FALLBACK_HABILITADO` (`false`) | `DATABASE_URL`, `API_SPORTS_KEY`, `BALLDONTLIE_API_KEY` (optional) |
| `statline/web` | 8080 | `/healthz` | — | — |

`/readyz` of the api also checks Redis when `REDIS_URL` is set. The api trusts one proxy hop (ingress-nginx, `trust proxy` = 1). With `api.ingestaLanzador: kubernetes` the chart mounts the ServiceAccount token and renders a Role (`get` on `cronjobs`, `create` on `jobs`, group `batch`) and RoleBinding in the release namespace; otherwise none of that is rendered (D-20).

CronJob args: `["run", "basquetbol"]`, `["run", "americano"]`, `["run", "futbol"]`. Exit code ≠ 0 marks the Job failed. All images run as non-root and work with `readOnlyRootFilesystem` (ingesta and predicciones need an `emptyDir` on `/tmp`).

## 6. CI/CD and GitOps

1. **CI (`ci.yml`, every repo, every push and PR):** lint and types; unit tests with a 70 % coverage gate (Vitest, Jest + Supertest, pytest); integration tests against an ephemeral PostgreSQL; multi-stage image builds; **Trivy** fails on HIGH/CRITICAL. Infra: `terraform fmt/validate`, `tflint`, `terraform plan` posted as a PR comment, and `helm lint --strict` plus `kubeconform` for the chart.
2. **Quality gate:** `develop` and `main` are protected: CI must pass and one reviewer must approve.
3. **Artifacts (app repos, `cd.yml`):** on push to `develop` or `main`, and on `vX.Y.Z` tags, each app repo pushes `statline/<image>:<short-sha>` (and `vX.Y.Z` on tags) to Docker Hub, scans the pushed image with Trivy, then sends `repository_dispatch` `bump-image` to this repo. `develop` → staging, `main` and tags → prod.
4. **Tag bump (`cd.yml` here):** validates the request (source repo allowlist, env, image, tag format), sets `<image>.image.tag` in `gitops/charts/statline/values-<env>.yaml` with `scripts/bump-image-tags.sh` (awk, keeps the file layout), runs `helm lint --strict` on that values file, and pushes `ci(gitops): bump …` to `develop` (staging) or `main` (prod) with `GITHUB_TOKEN`. Pushes that lose a race are retried after a rebase-free reset to `origin`. Manual runs: `workflow_dispatch` with env, image and tag.
5. **GitOps sync:** Argo CD watches `gitops/` and syncs `statline-staging` (from `develop`) and `statline-prod` (from `main`).
6. **Verify and roll back (planned SL-57):** a PostSync hook Job curls `/healthz` and `/readyz`; on failure Argo CD rolls back to the last healthy revision.

## 7. Branch strategy

- **Permanent:** `main` (production, `statline-prod`) and `develop` (staging, `statline-staging`, default branch). Both protected: no direct pushes, no force pushes, PR + green CI + 1 approval.
- **Temporary:** `feature/<issue>-<desc>` and `fix/<issue>-<desc>` from `develop`, back into `develop` (**squash merge**). `release/vX.Y.Z` from `develop` into `main` (**merge commit**) and back-merged into `develop`. `hotfix/vX.Y.Z` from `main` into `main` and `develop`.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `ci:`). **Versions:** SemVer tags `vX.Y.Z` on `main`. **Traceability:** every PR says `Closes #N`; merged branches are deleted automatically.

## 8. Operations

| Task | How |
|---|---|
| First deploy | `make bootstrap` → `make plan` → `make apply` → `az aks get-credentials` |
| Daily stop | `make destroy` (data is lost unless dumped: `pg_dump` through a client pod first) |
| DB shell | `kubectl run psql --rm -it --image=postgres:16-alpine -- psql "$DATABASE_URL"` |
| Rotate a secret | update it in Key Vault; the CSI driver re-syncs within 5 min; restart the Deployment |
| Local cluster | `make k3d-up`, then `make k3d-deploy` (Redis and the chart with `values-k3d.yaml`); the README in `gitops/` has the full steps |
