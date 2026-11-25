# statline-infra

Infrastructure for **StatLine**, a web platform for unified sports statistics and performance forecasts across three leagues: **NBA** (basketball), **NFL** (American football) and **Liga MX** (football). Scheduled jobs pull games and box scores from API-Sports, a REST API serves comparisons and standings, and a Python service produces match-outcome probabilities and player projections.

This repo holds:
- **Terraform** for every AWS resource (Learner Lab, D-38): `bootstrap` (S3 state bucket, ingress Elastic IP) and `principal` (VPC, EKS, RDS PostgreSQL, SSM parameters, CloudWatch logs, platform Helm releases)
- the `make` targets that bootstrap state, plan and apply
- a **k3d** setup for testing the Kubernetes manifests locally
- the **GitOps** charts (`gitops/charts/statline`, `gitops/charts/redis`) and the Argo CD applications that deploy the four images
- the project-wide docs: architecture, data model, API design, backlog and pending work

The app itself lives in [`statline-backend`](https://github.com/statline-iteso/statline-backend) and [`statline-frontend`](https://github.com/statline-iteso/statline-frontend).

## Proyecto final · ITESO, Otoño 2026

**Proyecto:** StatLine — Plataforma de Estadísticas y Pronósticos Deportivos Multideporte

| Integrante | Rol |
|---|---|
| Juan Pablo González | Backend, frontend y cimientos (primera mitad) |
| Ian Rodríguez | Infraestructura, predicciones y despliegue (segunda mitad) |

### Caso de uso de punta a punta

Cada mañana el CronJob `ingesta-basquetbol` consulta API-Sports, normaliza los partidos y las líneas de caja de la NBA, valida cada línea contra su JSON Schema y la guarda en PostgreSQL (JSONB con índice GIN). Un usuario inicia sesión en la web, revisa la tabla de posiciones, busca a un jugador y consulta su ficha. Antes de la jornada, el servicio de predicciones calcula las probabilidades de cada partido con el modelo activo registrado en `ModeloPrediccion`.

![Diagrama de la solución](docs/solucion.png)

Verde: implementado (aún sin aplicar en AWS). Línea punteada: opcional o respaldo. Fuente editable en [`docs/solucion.mmd`](docs/solucion.mmd) (`make diagram`).

### Repositorios

| Repo | Contiene |
|---|---|
| [statline-infra](https://github.com/statline-iteso/statline-infra) (este) | Terraform, k3d, chart GitOps y aplicaciones de Argo CD, documentación del proyecto |
| [statline-backend](https://github.com/statline-iteso/statline-backend) | `api` (Node 20 + Express + Prisma), `ingesta` y `predicciones` (Python 3.12), JSON Schemas, sus `Dockerfile` |
| [statline-frontend](https://github.com/statline-iteso/statline-frontend) | SPA en React 18 + Vite + Tailwind que consume la API |

### Entregables

| # | Entregable | Dónde |
|---|---|---|
| 1 | Diagrama de la solución | [docs/solucion.png](docs/solucion.png) |
| 2 | Modelo de datos | [docs/modelo-datos.md](docs/modelo-datos.md) |
| 3 | Diseño de la API | [docs/api.md](docs/api.md) |
| 4 | Código fuente | Backend: [statline-backend](https://github.com/statline-iteso/statline-backend) (`services/`, `schemas/`). Frontend: [statline-frontend](https://github.com/statline-iteso/statline-frontend). Infraestructura: [`terraform/`](terraform), [`k3d/`](k3d), [`scripts/`](scripts) |
| 5 | Backlog y tablero | [docs/BACKLOG.md](docs/BACKLOG.md) · [GitHub Project](https://github.com/orgs/statline-iteso/projects) |
| 6 | Pendientes | [docs/pendientes.md](docs/pendientes.md) |

### Avance

60 de 61 issues (273 de 277 puntos) están terminados. La primera mitad dejó los cimientos, los módulos de Terraform `bootstrap`, `red`, `aks` y `datos` (en Azure), la ingesta de NBA, la API con autenticación y el catálogo, y las vistas base del frontend. La segunda mitad agregó Key Vault, Log Analytics, DNS y la plataforma, y luego movió la infraestructura de Azure a AWS Learner Lab porque se negaron los créditos de Azure (EKS, RDS, SSM, D-38); el chart con Argo CD, Redis, HPA, NetworkPolicies, PDB, monitoreo y pruebas de humo; NFL, Liga MX y los respaldos; el resto de la API; los modelos de predicción; y las vistas de boxscore, comparación, pronósticos, listas y alertas. Staging ya se desplegó y verificó en AWS, con la evidencia en [docs/evidencia/](docs/evidencia/README.md) (SL-60). Falta SL-61 (release y defensa), en [docs/pendientes.md](docs/pendientes.md).

### Cómo correrlo

| Situación | Comandos | Tiempo |
|---|---|---|
| Sesión del lab (cada vez) | `make creds` (pega el bloque de AWS Details) | 1 min |
| Cuenta del lab nueva (una vez) | `make bootstrap` | ~3 min |
| Infraestructura en AWS | `make apply-eks` → `make plan` → `make apply` → `make kubeconfig` | ~25 min |
| Al terminar | `make destroy` (EKS, nodos, RDS y el NLB cuestan ~USD 0.30/h del presupuesto de USD 50) | ~15 min |
| Sin AWS | backend: `docker compose up -d --wait` y `pnpm --filter @statline/api dev` en su repo; frontend: `pnpm dev` | 2 min |
| Clúster local | `make k3d-up` / `make k3d-down` | ~2 min |

### Documentación de planeación

Roadmap por área y bitácora del proyecto: [resumen](docs/planning/README.md) · [infra](docs/planning/infra-plan.md) · [backend](docs/planning/back-plan.md) · [frontend](docs/planning/front-plan.md) · [changelog](docs/planning/changelog.md).

## Docs

| Read | For |
|---|---|
| [AGENTS.md](AGENTS.md) | Start here: scope, AWS Learner Lab constraints, stack, commands, repo layout, rules |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Every AWS resource, the cluster layout, CI/CD and GitOps flow, branch strategy |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md) | How Terraform, manifests, scripts and workflows are written |
| [docs/DECISIONS.md](docs/DECISIONS.md) | What we decided and why, known limitations, future work |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Every issue (61), by epic and sprint |

## Prerequisites

- An **AWS Academy Learner Lab** (us-east-1, `LabRole`); the lab keys go in with `make creds`
- **[mise](https://mise.jdx.dev)**, which installs every other CLI at the pinned version (see [Tooling](#tooling))
- **Docker**, for k3d and for building images
- **[GitHub CLI](https://cli.github.com)** (`gh`), with access to the three repos

## Tooling

All CLI versions are pinned in [`mise.toml`](mise.toml): terraform, tflint, kubectl, helm, kubeconform, k3d, aws-cli, shellcheck and pre-commit.

```bash
curl https://mise.run | sh        # or: brew install mise / winget install jdx.mise
mise install                      # installs every pinned tool for this repo
pre-commit install                # git hooks: fmt, validate, tflint, shellcheck
make help                         # every target
make creds                        # AWS Learner Lab, once per session: paste the AWS CLI block (AWS Details → AWS CLI → Show)
                                  #   → profile statline-lab + AWS_* secrets in statline-infra. FROM=clipboard reads pbpaste; SKIP_GH=1 local only
make check-creds                  # are the lab credentials still valid?
```

## First time on a lab account

The project runs on the AWS Learner Lab (D-38): EKS on the lab's `LabRole`, RDS PostgreSQL, SSM Parameter Store, us-east-1 only.

```bash
make creds                        # start of every lab session (see Tooling)
make bootstrap                    # once per lab account: S3 state bucket + ingress Elastic IP (local state);
                                  # asks before applying, then writes terraform/principal/backend.hcl
terraform -chdir=terraform/bootstrap output -raw ingress_ip   # hosts: staging.<ip>.nip.io and <ip>.nip.io
make apply-eks                    # step 1: only the EKS cluster and nodes (~15 min; the kubernetes/helm providers need it)
make plan                         # step 2: everything else (RDS, SSM, namespaces, platform charts, database Job)
make apply                        # asks before applying, then sets the API keys and Sentry DSNs (make secrets)
make kubeconfig                   # context eks-statline
terraform -chdir=terraform/principal output -raw grafana_admin_password   # Grafana, user admin
```

No tfvars are needed; `terraform/principal/terraform.tfvars.example` lists the optional overrides.

**Two-step first apply.** The `kubernetes` and `helm` providers talk to the cluster created in
`module.eks`. A single plan works (it plans 50 resources), but applying the charts in the same run
as the cluster relies on Terraform configuring those providers late. `make apply-eks` creates the
cluster alone first, so every later plan sees a real cluster (decision D-24).

**Argo CD UI** (no public Ingress yet): `kubectl -n plataforma port-forward svc/argo-cd-argocd-server 8080:80`.

> [!WARNING]
> **Run `make destroy` when you are done for the day** unless the cluster must stay up. The EKS control plane, 2 × t3.medium, RDS and the NLB bill about USD 0.30/h against the USD 50 lab budget. `make destroy` removes the platform charts first, waits for the ingress NLB to go, then destroys the rest. The bootstrap bucket and the Elastic IP stay (cents, plus ~USD 3.60/month for the IP).

### Recovering the bootstrap state

The `bootstrap` stack keeps its state locally (`terraform/bootstrap/terraform.tfstate`, gitignored) because it creates the bucket every other stack stores its state in. If that file is lost, or a first apply failed halfway, just run `make bootstrap` again: `scripts/bootstrap-account.sh` imports the existing bucket and Elastic IP before the plan, so it adopts them instead of creating a second Elastic IP (which would change the address). A state left over from another lab account is moved to `terraform/bootstrap/archive/<account>/`.
