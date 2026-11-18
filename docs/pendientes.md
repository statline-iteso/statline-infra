# Pendientes para la entrega final

Entregable 6. **Juan Pablo** González (backend, frontend, cimientos) e **Ian** Rodríguez (infraestructura, predicciones, despliegue). Lo implementado está en verde en el [diagrama](solucion.png); esta lista es lo que falta. Cada punto tiene su issue en el [tablero](https://github.com/orgs/statline-iteso/projects) y en [BACKLOG.md](BACKLOG.md).

**Avance:** 32 de 61 issues · 144 de 277 puntos (52 %).

## Infraestructura (statline-infra)

| # | Pendiente | Issue | Pts |
|---|---|---|---|
| 1 | Módulo `seguridad`: Key Vault con RBAC, secretos (`database-url-<env>`, `jwt-secret-<env>`, `jwt-refresh-secret-<env>`, `api-sports-key`) y rol *Key Vault Secrets User* para la identidad del CSI add-on (ya expuesta como output `key_vault_csi_identity_object_id`) | SL-09 | 5 |
| 2 | Módulo `observabilidad`: Log Analytics + diagnostic settings; conectar `oms_agent` en el módulo `aks` (hay un TODO) | SL-10 | 3 |
| 3 | Módulos `dns` y `plataforma`: zona DNS, IP pública del ingress y los cinco `helm_release` (ingress-nginx, cert-manager, argo-cd, kube-prometheus-stack, redis). Agregar los proveedores `kubernetes` y `helm` en `principal/versions.tf` | SL-12 | 6 |
| 4 | `gitops/`: chart Helm (Deployments web/api/predicciones, Services, Ingress, ConfigMaps, los 3 CronJob con sus horarios), `values-staging.yaml`, `values-prod.yaml`, Applications de Argo CD; en `cd.yml` de los repos de app (que ya publica en Docker Hub) falta el paso que actualiza la etiqueta aquí. El contrato de imágenes está en [ARCHITECTURE §5](ARCHITECTURE.md#5-contract-with-the-backend-images) | SL-53 | 7 |
| 5 | ServiceMonitors y dashboards de Grafana | SL-54 | 5 |
| 6 | HPA de api (2–6, 70 % CPU) y predicciones (1–4, 75 % CPU) | SL-55 | 3 |
| 7 | NetworkPolicies default-deny y PDBs | SL-56 | 4 |
| 8 | Job de pruebas de humo (PostSync) y rollback de Argo CD | SL-57 | 4 |
| 9 | SecretProviderClass por ambiente | SL-58 | 2 |
| 10 | Evidencia de despliegue y runbook | SL-60 | 4 |
| 11 | Entrega final: release `v1.0.0` y defensa | SL-61 | 4 |

## Backend (statline-backend)

| # | Pendiente | Issue | Pts |
|---|---|---|---|
| 12 | Adaptador de Liga MX (api-football, liga 262) siguiendo `AdaptadorBasquetbol` | SL-17 | 5 |
| 13 | Adaptador de NFL (api-american-football, liga 1) | SL-18 | 5 |
| 14 | Proveedores de respaldo balldontlie.io y TheSportsDB | SL-20 | 6 |
| 15 | `/api/jugadores/:id/promedios`, `/tendencia` y `/comparar?ids=` (hay un TODO en `routes/catalogo.ts`) | SL-27 | 5 |
| 16 | `/api/estadisticas` y `/api/listas` | SL-28 | 5 |
| 17 | `/api/pronosticos`, `/api/proyecciones`, `/api/modelos` (proxy a predicciones) | SL-29 | 4 |
| 18 | `/api/alertas` e `/api/ingestas` | SL-30 | 3 |
| 19 | Caché y rate limit con Redis; `/readyz` revisa Redis | SL-31 | 3 |
| 20 | Predicciones: extracción de características | SL-33 | 5 |
| 21 | Predicciones: regresión logística (resultado y marcador esperado) | SL-34 | 8 |
| 22 | Predicciones: Gradient Boosting (proyecciones por jugador) | SL-35 | 8 |
| 23 | Predicciones: registro y activación en `ModeloPrediccion` | SL-36 | 5 |
| 24 | Predicciones: `/generar` escribe pronósticos y proyecciones (hoy responden 501) | SL-37 | 4 |
| 25 | Predicciones: `/precision` y `/reentrenar` | SL-38 | 3 |

## Frontend (statline-frontend)

| # | Pendiente | Issue | Pts |
|---|---|---|---|
| 26 | Boxscore con Tailwind y Recharts (ruta `partidos/:id`) | SL-44 | 5 |
| 27 | Comparación de jugadores y equipos | SL-45 | 4 |
| 28 | Vistas de pronósticos y proyecciones | SL-46 | 4 |
| 29 | Listas de seguimiento y alertas | SL-47 | 4 |

## Configuración que falta en GitHub y Azure

- **Secrets de CI (infra):** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (app registration con credencial federada para GitHub OIDC) y `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT` (salen de `make bootstrap`). Sin ellos el job `plan` se salta.
- **Secrets de CD (app repos `statline-backend` y `statline-frontend`):** `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN` (push a Docker Hub) e `INFRA_DISPATCH_TOKEN`, un PAT fino con `contents: write` sobre `statline-infra` (solo para el `repository_dispatch`). Sin ellos `cd.yml` termina sin publicar.
- **Permiso de escritura del bot en infra:** `cd.yml` de infra hace `git push` con `GITHUB_TOKEN` a `develop` (staging) y `main` (prod). Las ramas protegidas deben permitir a `github-actions[bot]` hacer push (Settings → Rulesets → bypass), o cambiar el paso de push por un PR con auto-merge (ver DECISIONS D-21). Sin esto el workflow falla en el push.
- **Docker Hub:** crear los repositorios `statline/web`, `statline/api`, `statline/predicciones` y `statline/ingesta` y el token de acceso antes de la primera ejecución de `cd.yml`.
- **Auto-merge:** `auto-merge.yml` aprueba y hace squash merge de los PRs de Ian hacia `develop` cuando el CI requerido pasa. Requiere activar *Allow GitHub Actions to create and approve pull requests* en la organización y en cada repo (Settings → Actions → General).
- **AKS 1.30:** confirmar con `az aks get-versions -l eastus2` que se puede crear; si no, usar la versión soportada más antigua y registrarlo en DECISIONS.

## Riesgos y plan B

| Riesgo | Impacto | Plan B |
|---|---|---|
| Dependencia de la API externa | Alto | La ingesta ya está desacoplada (lecturas 100 % desde la base) y respeta la cuota; faltan los respaldos (SL-20) |
| Agotamiento de créditos de Azure | Crítico | Nodos Standard_B2s, `make destroy` al terminar cada sesión, presupuesto con alerta en el portal |
| Precisión pobre de los modelos | Medio | Comparar siempre contra un baseline y versionar en `ModeloPrediccion`; activar solo si mejora |
| Alcance excesivo | Alto | Orden estricto: 1º NBA (hecho), 2º NFL, 3º Liga MX; entrega viable con dos deportes |
