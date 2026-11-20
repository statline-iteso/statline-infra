# Pendientes para la entrega final

Entregable 6. **Juan Pablo** González (backend, frontend, cimientos) e **Ian** Rodríguez (infraestructura, predicciones, despliegue). Todo lo del [diagrama](solucion.png) está implementado; esta lista es lo que falta para la entrega. Cada punto tiene su issue en el [tablero](https://github.com/orgs/statline-iteso/projects) y en [BACKLOG.md](BACKLOG.md).

**Avance:** 59 de 61 issues · 269 de 277 puntos (97 %). El código está completo y fusionado en `develop` de los tres repos (PRs del 18 de noviembre de 2026). Nada está desplegado ni publicado todavía: falta cargar los secrets y aplicar en Azure.

## Lo que falta

| # | Pendiente | Issue | Pts |
|---|---|---|---|
| 1 | Desplegar en Azure (`make bootstrap`, `make plan`, `make apply`, primera sincronización de Argo CD) y juntar la evidencia: capturas de AKS, Argo CD, Grafana y pruebas de humo. El runbook está en [RUNBOOK.md](RUNBOOK.md) | SL-60 | 4 |
| 2 | Release `v1.0.0`: PRs `develop → main` en los tres repos (los revisa Juan Pablo), etiqueta y notas; presentación y demo de punta a punta | SL-61 | 4 |

## Decisiones que faltan al desplegar

- Correo de contacto de los ClusterIssuers (`gitops/plataforma/cluster-issuers.yaml`, hoy `change-me@example.com`).
- Dominio (`dominio`) o nip.io; sin dominio el módulo `dns` no se crea.
- Valores reales de `api-sports-key` y `balldontlie-api-key` en Key Vault (Terraform deja marcadores).
- `networkPolicies.kubeApiCidr` solo si se usa `api.ingestaLanzador: kubernetes`.
- Versión de AKS (abajo).
- Correr una ingesta real por deporte después del despliegue: los adaptadores de NFL y Liga MX y los respaldos se armaron con la documentación de los proveedores y nunca se probaron contra una respuesta real (backend D-24, D-25, D-27).

## Configuración que falta en GitHub y Azure

- **Secrets de CI (infra):** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (app registration con credencial federada para GitHub OIDC) y `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT` (salen de `make bootstrap`). Sin ellos el job `plan` se salta.
- **Secrets de CD (app repos `statline-backend` y `statline-frontend`):** `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` (push a Docker Hub) e `INFRA_DISPATCH_TOKEN`, un PAT fino con `contents: write` sobre `statline-infra` (solo para el `repository_dispatch`). Sin ellos `cd.yml` termina sin publicar.
- **Token del bump en infra:** `GITOPS_PR_TOKEN` en `statline-infra`, un PAT fino con `contents: write` y `pull-requests: write` sobre `statline-infra` (puede ser el mismo que `INFRA_DISPATCH_TOKEN` si se le agrega `pull-requests: write`). `cd.yml` de infra lo usa para empujar `gitops/bump-<env>` y abrir el PR; sin él el workflow falla (D-36). No hace falta relajar la protección de ramas.
- **Docker Hub:** crear los repositorios `statline/web`, `statline/api`, `statline/predicciones` y `statline/ingesta` y el token de acceso antes de la primera ejecución de `cd.yml`.
- **Auto-merge (listo):** `auto-merge.yml` aprueba y hace squash merge de los PRs de Ian (y de los bump PRs de staging) hacia `develop` cuando el CI requerido pasa, y luego arranca `ci.yml` en `develop`, porque los merges con `GITHUB_TOKEN` no disparan `push`.
- **AKS 1.30:** confirmar con `az aks get-versions -l eastus2` que se puede crear; si no, usar la versión soportada más antigua y registrarlo en DECISIONS.

## Riesgos y plan B

| Riesgo | Impacto | Plan B |
|---|---|---|
| Dependencia de la API externa | Alto | La ingesta está desacoplada (lecturas 100 % desde la base), respeta la cuota y cambia a balldontlie o TheSportsDB si API-Sports falla; los datos de demo (`ingesta seed-demo`) sirven para la presentación sin API key |
| Mapeo de campos sin verificar en vivo | Medio | Una ingesta real por deporte al desplegar; si un campo no cuadra, se corrige el adaptador con la respuesta grabada como fixture |
| Agotamiento de créditos de Azure | Crítico | Nodos Standard_B2s, `make destroy` al terminar cada sesión, presupuesto con alerta en el portal |
| Precisión pobre de los modelos | Medio | Siempre contra un baseline, versionado en `ModeloPrediccion`; solo se activa si mejora (backend D-31) |
