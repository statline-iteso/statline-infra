# StatLine: roadmap

How the project is delivered across its three repos: the sprints, what each area has built, what comes next and how the repos depend on each other.

ITESO final project, Fall 2026: **Juan Pablo** (backend, frontend, foundations) and **Ian** (infra, predictions, deployment).

## Notes in this folder

| Area | Plan | Decisions | Repo |
|---|---|---|---|
| **Infra** | [Infra plan](infra-plan.md) | [Infra decisions](../DECISIONS.md) | `statline-infra` |
| **Back** | [Back plan](back-plan.md) | [Back decisions](https://github.com/statline-iteso/statline-backend/blob/develop/docs/DECISIONS.md) | `statline-backend` |
| **Front** | [Front plan](front-plan.md) | [Front decisions](https://github.com/statline-iteso/statline-frontend/blob/develop/docs/DECISIONS.md) | `statline-frontend` |
| All | this note | [Changelog](changelog.md) | |

## Sprints

| Sprint | Weeks | Goal | Status |
|---|---|---|---|
| S0 | 1 | Repos, devcontainers, linters, k3d, JSON Schemas | ✅ Done |
| S1 | 2–3 | Terraform: bootstrap, red, aks, datos, remote state | ✅ Done (Argo CD moves to S5 with the chart) |
| S2 | 4–5 | Prisma schema (tables + JSONB), NBA ingestion end to end | ✅ Done · Key Vault, Log Analytics, DNS/plataforma pending |
| S3 | 6–7 | API core, JWT auth, CI in the three repos, Trivy gate | ✅ Done |
| S4 | 8–9 | Models in FastAPI, React views, NFL and Liga MX | 🟡 Front base views done; models, adapters, comparison pending |
| S5 | 10–11 | GitOps + Argo CD, Prometheus/Grafana, HPA, resilience | ⏳ Next |
| S6 | 12 | Quality pass, smoke tests, delivery and defense | ⏳ |

## Dependencies between repos

- The **chart** (infra, SL-53) needs the images and the contract in backend ARCHITECTURE §8 — both exist.
- **cd.yml** in backend/frontend needs Docker Hub secrets and a dispatch token for infra.
- **Frontend** pronósticos/proyecciones views (SL-46) need backend SL-29 and predicciones SL-34..37.
- **Key Vault** (SL-09) must exist before the SecretProviderClass (SL-58) and the first real deploy.
