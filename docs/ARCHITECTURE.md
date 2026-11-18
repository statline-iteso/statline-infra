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
| `datos` | done | `psql-statline-<5>` PostgreSQL 16 `B_Standard_B1ms`, 32 GiB auto-grow, 7-day backups, private access only, `require_secure_transport=on` · databases `statline_staging` and `statline_prod` (`prevent_destroy`, D-16) · admin password from `random_password` |
| `seguridad` | done | `kv-statline-<5>` Standard, RBAC (`rbac_authorization_enabled`), soft delete 7 days, purge protection off, public access with default Allow (D-18) · *Key Vault Secrets Officer* for the deployer · *Key Vault Secrets User* for the CSI add-on identity · secrets below |
| `observabilidad` | planned (SL-10) | `log-statline` (30 days) · `diagnostic_settings` for AKS, PostgreSQL, Key Vault · AKS `oms_agent` |
| `dns` | planned (SL-12) | `dns_zone` · `public_ip` for the ingress (in the node resource group) · A record |
| `plataforma` | planned (SL-12) | `helm_release`: ingress-nginx, cert-manager, argo-cd, kube-prometheus-stack, redis (Bitnami) — all in `plataforma` |

Outputs other repos or the chart rely on: `aks_cluster_name`, `resource_group_name`, `key_vault_csi_identity_client_id`, `postgres_fqdn`, `key_vault_name`, `key_vault_uri`, `tenant_id` (for the SecretProviderClass). `database_url` was removed: the URLs live only in Key Vault. Renaming one is a contract change.

### Key Vault secrets (contract)

Names are fixed; the SecretProviderClass (SL-58) and the backend read them by these names. `<env>` is `staging` or `prod`.

| Secret | Value | Per env | Source |
|---|---|---|---|
| `database-url-<env>` | `DATABASE_URL` for `statline_<env>` (admin login, `sslmode=require`) | yes | `module.datos.database_urls` |
| `jwt-secret-<env>` | `JWT_SECRET`, 64 chars | yes | `random_password` |
| `jwt-refresh-secret-<env>` | `JWT_REFRESH_SECRET`, 64 chars | yes | `random_password` |
| `api-sports-key` | `API_SPORTS_KEY` | no (one quota for all envs) | placeholder `set-me`, set out of band; Terraform ignores later changes |

The Kubernetes Secret `statline-secrets` maps these to the env names the images expect (§5).
| `aks` | done | `id-statline-aks` (user-assigned) with *Network Contributor* on `snet-aks` · `aks-statline` 1.30, node pool `system` 2→4 × Standard_B2s, Azure CNI, Azure network policy, service CIDR 10.1.0.0/16, OIDC issuer, workload identity, Key Vault Secrets Store CSI add-on (rotation 5 min), `oms_agent` (Container Insights, MSI auth) to `log-statline` |
| `datos` | done | `psql-statline-<5>` PostgreSQL 16 `B_Standard_B1ms`, 32 GiB auto-grow, 7-day backups, private access only, `require_secure_transport=on` · database `statline` (`prevent_destroy`) · admin password from `random_password` |
| `seguridad` | planned (SL-09) | `kv-statline-<5>` (RBAC, purge protection, network ACLs) · secrets `database-url`, `jwt-secret`, `jwt-refresh-secret`, `api-sports-key` · *Key Vault Secrets User* for the CSI add-on identity |
| `observabilidad` | done (SL-10) | `log-statline` Log Analytics, PerGB2018, 30 days retention, daily cap 0.5 GB (`log_analytics_daily_quota_gb`) · one `azurerm_monitor_diagnostic_setting` per entry of `recursos_diagnostico` (`diag-aks`, `diag-postgres`), destination *Dedicated* tables. AKS: `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `cluster-autoscaler`, `guard` + AllMetrics. PostgreSQL: `allLogs` group + AllMetrics. Key Vault: pending, see below |
| `dns` | planned (SL-12) | `dns_zone` · `public_ip` for the ingress (in the node resource group) · A record |
| `plataforma` | planned (SL-12) | `helm_release`: ingress-nginx, cert-manager, argo-cd, kube-prometheus-stack, redis (Bitnami) — all in `plataforma` |

Outputs other repos or the chart rely on: `aks_cluster_name`, `resource_group_name`, `key_vault_csi_identity_client_id`, `postgres_fqdn`, `database_url` (sensitive), `log_analytics_workspace_id`, `log_analytics_workspace_name`. Renaming one is a contract change.

**Key Vault diagnostics (pending):** the `seguridad` module (SL-09) is on a parallel branch. Once both merge, add `kv = { resource_id = module.seguridad.key_vault_id }` to `recursos_diagnostico` in `principal/main.tf` (module observabilidad, SL-10 follow-up). Until then Key Vault logs are not sent to Log Analytics.

### Why private access for PostgreSQL

With a delegated subnet the server has no public endpoint, so the proposal's "firewall rules" are replaced by the network boundary: only the VNet (AKS pods) can reach it. Admin access for humans goes through `kubectl run` with a `postgres:16` client pod or `kubectl port-forward` to a pod (D-06).

## 4. Cluster layout (planned SL-53 and E8)

| Object | Count | Detail |
|---|---|---|
| Namespace | 3 | `plataforma`, `statline-staging`, `statline-prod` |
| Deployment | 3 per env | `web` (2 replicas), `api`, `predicciones` |
| StatefulSet | 1 | Redis (Bitnami chart, in `plataforma`) |
| CronJob | 3 per env | `ingesta-basquetbol` `0 8 * * *` · `ingesta-americano` `0 8 * * 2` · `ingesta-futbol` `0 8 * * 1,5` (UTC) |
| Service | 4 | ClusterIP for web, api, predicciones and Redis |
| Ingress | 1 per env | `/` → web, `/api` → api; TLS via cert-manager |
| HPA | 2 per env | api 2–6 at 70 % CPU; predicciones 1–4 at 75 % CPU |
| ConfigMap | 1 per component | non-secret settings (ports, `PREDICCIONES_URL`, `TEMPORADA_*`, log level) |
| SecretProviderClass | 1 per env | mounts the Key Vault secrets and syncs a Kubernetes Secret `statline-secrets` |
| NetworkPolicy | per env | `default-deny-ingress` + allow ingress-nginx → web/api, api → predicciones, Prometheus → `/metrics` |
| PodDisruptionBudget | per env | `minAvailable: 1` for web and api |

The api Deployment has an **initContainer** that runs `prisma migrate deploy` with the same image (`node_modules/.bin/prisma migrate deploy`), so the schema is migrated before the new version serves traffic.

## 5. Contract with the backend images

Source of truth: backend `docs/ARCHITECTURE.md §8`. Summary:

| Image | Port | Probes | Env (ConfigMap) | Env (Secret) |
|---|---|---|---|---|
| `statline/api` | 3000 | `/healthz`, `/readyz` | `PORT`, `PREDICCIONES_URL`, `REDIS_URL`, `LOG_LEVEL`, `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL` | `DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET` |
| `statline/predicciones` | 8000 | `/healthz`, `/readyz` | `ARTEFACTOS_DIR`, `LOG_LEVEL` | `DATABASE_URL` |
| `statline/ingesta` | 8080 (`serve`) | `/healthz`, `/readyz` | `TEMPORADA_BASQUETBOL`, `TEMPORADA_AMERICANO`, `TEMPORADA_FUTBOL`, `API_SPORTS_DAILY_QUOTA` | `DATABASE_URL`, `API_SPORTS_KEY` |
| `statline/web` | 8080 | `/healthz` | — | — |

CronJob args: `["run", "basquetbol"]`, `["run", "americano"]`, `["run", "futbol"]`. Exit code ≠ 0 marks the Job failed. All images run as non-root and work with `readOnlyRootFilesystem` (ingesta and predicciones need an `emptyDir` on `/tmp`).

## 6. CI/CD and GitOps

1. **CI (`ci.yml`, every repo, every push and PR):** lint and types; unit tests with a 70 % coverage gate (Vitest, Jest + Supertest, pytest); integration tests against an ephemeral PostgreSQL; multi-stage image builds; **Trivy** fails on HIGH/CRITICAL. Infra: `terraform fmt/validate`, `tflint`, and `terraform plan` posted as a PR comment.
2. **Quality gate:** `develop` and `main` are protected: CI must pass and one reviewer must approve.
3. **Artifacts (`cd.yml`, planned SL-53):** on merge, push `statline/<image>:<short-sha>` (and `vX.Y.Z` on release branches) to Docker Hub, then commit the new tag to `gitops/values-<env>.yaml` in this repo.
4. **GitOps sync (planned SL-53):** Argo CD watches `gitops/` and syncs `statline-staging` (from `develop`) and `statline-prod` (from `main`).
5. **Verify and roll back (planned SL-57):** a PostSync hook Job curls `/healthz` and `/readyz`; on failure Argo CD rolls back to the last healthy revision.

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
| Local cluster | `make k3d-up`, then `helm install` the chart with `values-local.yaml` (SL-53) |
