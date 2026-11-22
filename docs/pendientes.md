# Pendientes para la entrega final

Entregable 6. **Juan Pablo** González (backend, frontend, cimientos) e **Ian** Rodríguez (infraestructura, predicciones, despliegue). Todo lo del [diagrama](solucion.png) está implementado; esta lista es lo que falta para la entrega. Cada punto tiene su issue en el [tablero](https://github.com/orgs/statline-iteso/projects) y en [BACKLOG.md](BACKLOG.md).

**Avance:** 59 de 61 issues · 269 de 277 puntos (97 %). El código está completo y fusionado en `develop` de los tres repos (PRs del 18 de noviembre de 2026). Nada está desplegado ni publicado todavía. Como se negaron los créditos de Azure, la infraestructura se movió a AWS Learner Lab (EKS, RDS, SSM; DECISIONS D-38, issue #50). El bootstrap ya está aplicado (bucket de estado e IP elástica 52.71.150.91); falta aplicar `principal`.

## Lo que falta

| # | Pendiente | Issue | Pts |
|---|---|---|---|
| 1 | Desplegar en AWS (`make creds`, `make apply-eks`, `make plan`, `make apply`, primera sincronización de Argo CD) y juntar la evidencia: capturas de EKS, Argo CD, Grafana y pruebas de humo. El runbook está en [RUNBOOK.md](RUNBOOK.md) | SL-60 | 4 |
| 2 | Release `v1.0.0`: PRs `develop → main` en los tres repos (los revisa Juan Pablo), etiqueta y notas; presentación y demo de punta a punta | SL-61 | 4 |

## Decisiones que faltan al desplegar

- Valores reales de `/statline/comun/api-sports-key` y `/statline/comun/balldontlie-api-key` en SSM (Terraform deja marcadores; RUNBOOK 2.2).
- `networkPolicies.kubeApiCidr` solo si se usa `api.ingestaLanzador: kubernetes`.
- Correr una ingesta real por deporte después del despliegue: los adaptadores de NFL y Liga MX y los respaldos se armaron con la documentación de los proveedores y nunca se probaron contra una respuesta real (backend D-24, D-25, D-27).

## Configuración que falta en GitHub y AWS

- **Secrets de CI (infra, listo):** `make creds` guarda las llaves del lab como `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`. Expiran con cada sesión; cuando expiran, el job `plan` se salta con un aviso.
- **Secrets de CD (app repos `statline-backend` y `statline-frontend`):** `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` (push a Docker Hub) e `INFRA_DISPATCH_TOKEN`, un PAT fino con `contents: write` sobre `statline-infra` (solo para el `repository_dispatch`). Sin ellos `cd.yml` termina sin publicar.
- **Token del bump en infra:** `GITOPS_PR_TOKEN` en `statline-infra`, un PAT fino con `contents: write` y `pull-requests: write` sobre `statline-infra` (puede ser el mismo que `INFRA_DISPATCH_TOKEN` si se le agrega `pull-requests: write`). `cd.yml` de infra lo usa para empujar `gitops/bump-<env>` y abrir el PR; sin él el workflow falla (D-36). No hace falta relajar la protección de ramas.
- **Docker Hub:** las imágenes van a la cuenta `pardosito` (`pardosito/{web,api,predicciones,ingesta}`; el primer push crea cada repositorio). Hace falta el token de acceso y la variable `DOCKERHUB_NAMESPACE=pardosito` en backend y frontend antes de la primera ejecución de `cd.yml`.
- **Auto-merge (listo):** `auto-merge.yml` aprueba y hace squash merge de los PRs de Ian (y de los bump PRs de staging) hacia `develop` cuando el CI requerido pasa, y luego arranca `ci.yml` en `develop`, porque los merges con `GITHUB_TOKEN` no disparan `push`.
- **EKS 1.35:** en soporte estándar al 2026-11-21 (D-38). Si sale del soporte estándar, cambiar `kubernetes_version` y registrarlo en DECISIONS.

## Riesgos y plan B

| Riesgo | Impacto | Plan B |
|---|---|---|
| Dependencia de la API externa | Alto | La ingesta está desacoplada (lecturas 100 % desde la base), respeta la cuota y cambia a balldontlie o TheSportsDB si API-Sports falla; los datos de demo (`ingesta seed-demo`) sirven para la presentación sin API key |
| Mapeo de campos sin verificar en vivo | Medio | Una ingesta real por deporte al desplegar; si un campo no cuadra, se corrige el adaptador con la respuesta grabada como fixture |
| Agotamiento del presupuesto del lab (USD 50) | Crítico | 2 nodos t3.medium y RDS db.t3.micro (~USD 0.31/h), sin NAT gateway, `make destroy` al terminar cada sesión; revisar el gasto del lab en cada sesión |
| Restricciones ocultas del lab | Alto | El lab no deja leer sus políticas: un `AccessDenied` aparece hasta el apply. Cada uno se documenta en D-38 con su solución |
| Precisión pobre de los modelos | Medio | Siempre contra un baseline, versionado en `ModeloPrediccion`; solo se activa si mejora (backend D-31) |
