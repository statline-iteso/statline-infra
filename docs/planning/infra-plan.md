# Infra plan

Back to the [roadmap](README.md).

## Built

- `terraform/bootstrap`: state storage account with Entra ID auth, versioning and soft delete (SL-05)
- `terraform/principal` with remote state and blob-lease locking (SL-11)
- Modules `red` (SL-06), `aks` (SL-07), `datos` (SL-08); `terraform validate` and `tflint` (azurerm ruleset) clean
- `make` targets, k3d cluster, pre-commit, mise, CI with fmt/validate/tflint and a plan job that comments on PRs (SL-04, SL-51)
- Project docs: architecture, data model, API design, diagram (SL-59)

## Next (in order)

1. **SL-09 seguridad** — Key Vault and the four secrets; the database URL already comes from `module.datos.database_url`.
2. **SL-12 dns + plataforma** — add the `kubernetes`/`helm` providers using `module.aks.kube_config`; five helm releases into `plataforma`.
3. **SL-53 gitops** — chart, values, Argo CD Applications, `cd.yml`. Follow ARCHITECTURE §4–5.
4. **SL-58, SL-55, SL-56** — SecretProviderClass, HPA, NetworkPolicies + PDBs.
5. **SL-10, SL-54** — Log Analytics and dashboards.
6. **SL-57, SL-60, SL-61** — smoke tests and rollback, evidence, release v1.0.0.

## Risks

- AKS 1.30 availability in the region (DECISIONS §3).
- Student credit: keep `make destroy` in the routine.
