# StatLine Backlog

The whole project backlog (proposal §6): **61 issues, 277 story points, nine epics**. Each issue lives in the repo that owns the work; the [GitHub Project](https://github.com/orgs/statline-iteso/projects) shows all of them on one board with the fields Épica, Sprint, Estimación and Prioridad. Per-repo views: [backend](https://github.com/statline-iteso/statline-backend/blob/develop/docs/BACKLOG.md) · [frontend](https://github.com/statline-iteso/statline-frontend/blob/develop/docs/BACKLOG.md).

**Progress:** 32 of 61 issues done · 144 of 277 points.

**How to read it**

- ✅ done in the first half · ⏳ pending (second half, Ian Rodríguez).
- One issue = one PR (`feature/<issue>-<desc>` → `develop`, squash merge, `Closes #N`).
- Board columns: Backlog → Listo para trabajar → En progreso → En revisión → Terminado.

## Epics

| Epic | Name | Issues | Points | Done |
|---|---|---|---|---|
| E1 | Cimientos del repositorio | 4 | 14 | 14 |
| E2 | Infraestructura con Terraform | 8 | 42 | 28 |
| E3 | Servicio de ingesta | 9 | 45 | 29 |
| E4 | API y modelo de datos | 10 | 48 | 28 |
| E5 | Servicio de predicciones | 8 | 38 | 5 |
| E6 | Frontend | 9 | 36 | 19 |
| E7 | Pipeline de CI/CD | 5 | 24 | 17 |
| E8 | Observabilidad y resiliencia | 5 | 18 | 0 |
| E9 | Documentación y entrega | 3 | 12 | 4 |
| **Total** | | **61** | **277** | **144** |

## Sprints

| Sprint | Weeks |
|---|---|
| S0 | Sem. 1 |
| S1 | Sem. 2 y 3 |
| S2 | Sem. 4 y 5 |
| S3 | Sem. 6 y 7 |
| S4 | Sem. 8 y 9 |
| S5 | Sem. 10 y 11 |
| S6 | Sem. 12 |

## E1 · Cimientos del repositorio

### ✅ [SL-01](https://github.com/statline-iteso/statline-infra/issues/1) · Inicializar repositorios, ramas main/develop y plantillas de PR e issues

**Sprint:** S0 · **Points:** 3 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] Tres repos en la organización: statline-infra, statline-backend, statline-frontend
- [x] Ramas `main` y `develop`; `develop` es la rama por defecto
- [x] Plantillas de PR (con `Closes #N`) e issues, CODEOWNERS, .editorconfig y .gitignore
- [x] README, AGENTS.md y docs/ (ARCHITECTURE, CONVENTIONS, DECISIONS, BACKLOG) en cada repo

### ✅ [SL-02](https://github.com/statline-iteso/statline-backend/issues/1) · Devcontainers y versiones fijadas de herramientas

**Sprint:** S0 · **Points:** 3 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] `.devcontainer/devcontainer.json` en backend y frontend (Node 20, Python 3.12, uv, pnpm)
- [x] Versiones fijadas: `.nvmrc`, `.python-version`, `packageManager`, `mise.toml` en infra
- [x] `docker-compose.yml` con PostgreSQL 16 y Redis 7 para desarrollo local

### ✅ [SL-03](https://github.com/statline-iteso/statline-backend/issues/2) · Definir esquemas JSON Schema para métricas de NBA, NFL y Liga MX

**Sprint:** S0 · **Points:** 3 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] `schemas/basquetbol.schema.json`, `americano.schema.json` y `futbol.schema.json` (draft 2020-12)
- [x] `additionalProperties: false` y mínimos en cada métrica
- [x] Pruebas con casos válidos e inválidos por deporte

### ✅ [SL-04](https://github.com/statline-iteso/statline-infra/issues/2) · Linters globales (ESLint, Prettier, ruff, mypy, tflint) y clúster local k3d

**Sprint:** S0 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] ESLint + Prettier en api y web; ruff + mypy strict en ingesta y predicciones; tflint en Terraform
- [x] `make k3d-up` / `make k3d-down` crean y destruyen el clúster local con ingress
- [x] `.pre-commit-config.yaml` en infra

## E2 · Infraestructura con Terraform

### ✅ [SL-05](https://github.com/statline-iteso/statline-infra/issues/3) · Módulo bootstrap: resource group, storage account y contenedor de estado

**Sprint:** S1 · **Points:** 5 · **Priority:** Crítica · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] `terraform/bootstrap` crea RG, storage account (TLS 1.2, sin acceso público) y contenedor `tfstate`
- [x] Estado local del bootstrap documentado (cómo recuperarlo)
- [x] `terraform validate` y `tflint` sin errores

### ✅ [SL-06](https://github.com/statline-iteso/statline-infra/issues/4) · Módulo red: VNet 10.0.0.0/16, subredes delegadas, NSG y DNS privado

**Sprint:** S1 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] VNet 10.0.0.0/16 con subred AKS y subred delegada a PostgreSQL Flexible Server
- [x] NSG asociado a la subred de AKS
- [x] Zona `privatelink.postgres.database.azure.com` enlazada a la VNet

### ✅ [SL-07](https://github.com/statline-iteso/statline-infra/issues/5) · Módulo aks: clúster 1.30, node pool Standard_B2s (2→4) e identidad

**Sprint:** S1 · **Points:** 8 · **Priority:** Crítica · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] AKS 1.30 con autoscaler 2–4 nodos Standard_B2s, Azure CNI y network policy
- [x] `user_assigned_identity` para el control plane y asignación de rol sobre la subred
- [x] Add-on Secrets Store CSI Driver habilitado; OIDC issuer y workload identity activos

### ✅ [SL-08](https://github.com/statline-iteso/statline-infra/issues/6) · Módulo datos: PostgreSQL Flexible Server B_Standard_B1ms con acceso privado

**Sprint:** S1 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] Servidor PostgreSQL 16 SKU B_Standard_B1ms en la subred delegada (sin acceso público)
- [x] Base `statline` y extensiones permitidas
- [x] Contraseña de administrador generada (`random_password`) y expuesta solo como output sensible

### ⏳ [SL-09](https://github.com/statline-iteso/statline-infra/issues/7) · Módulo seguridad: Key Vault, secretos y políticas de acceso

**Sprint:** S2 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] `azurerm_key_vault` con RBAC, purge protection y acceso de red restringido
- [ ] Secretos: DATABASE_URL, JWT_SECRET, JWT_REFRESH_SECRET, API_SPORTS_KEY
- [ ] Rol `Key Vault Secrets User` para la identidad del CSI driver

### ⏳ [SL-10](https://github.com/statline-iteso/statline-infra/issues/8) · Módulo observabilidad: Log Analytics y diagnostic settings

**Sprint:** S2 · **Points:** 3 · **Priority:** Media · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] `log_analytics_workspace` con retención de 30 días
- [ ] `diagnostic_settings` para AKS, PostgreSQL y Key Vault hacia Log Analytics

### ✅ [SL-11](https://github.com/statline-iteso/statline-infra/issues/9) · Configurar backend remoto Azure Storage para state locking en Terraform

**Sprint:** S1 · **Points:** 5 · **Priority:** Crítica · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] `backend "azurerm"` en el stack principal con `use_azuread_auth`
- [x] `backend.hcl` generado por `make backend-config` (gitignored) desde los outputs del bootstrap
- [x] Bloqueo por lease del blob comprobado con dos `plan` simultáneos

### ⏳ [SL-12](https://github.com/statline-iteso/statline-infra/issues/10) · Módulos dns y plataforma: zona DNS, IP pública y cinco helm_release

**Sprint:** S2 · **Points:** 6 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] `dns_zone` y registro A hacia la `public_ip` del ingress
- [ ] helm_release: ingress-nginx, cert-manager, argo-cd, kube-prometheus-stack y redis (Bitnami)
- [ ] Versiones de charts fijadas en variables

## E3 · Servicio de ingesta

### ✅ [SL-13](https://github.com/statline-iteso/statline-backend/issues/3) · Esqueleto del servicio de ingesta (Python 3.12, uv, configuración y probes)

**Sprint:** S2 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] Paquete `ingesta` con `pyproject.toml`, uv.lock, ruff y mypy strict
- [x] Configuración por variables de entorno (pydantic-settings)
- [x] `ingesta serve` expone /healthz, /readyz y /metrics

### ✅ [SL-14](https://github.com/statline-iteso/statline-backend/issues/4) · Persistencia en PostgreSQL y auditoría en EjecucionIngesta

**Sprint:** S2 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] Upserts idempotentes de equipo, jugador, partido y estadística (mismas llaves únicas que Prisma)
- [x] Cada corrida registra EN_CURSO → EXITOSA/FALLIDA, registros y peticiones usadas
- [x] Prueba de integración contra PostgreSQL 16 con las migraciones aplicadas

### ✅ [SL-15](https://github.com/statline-iteso/statline-backend/issues/5) · Validación estricta de métricas contra JSON Schema antes de insertar

**Sprint:** S2 · **Points:** 3 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] Cada línea se valida contra `schemas/<deporte>.schema.json`
- [x] Las líneas inválidas se descartan y se registran sin abortar el partido

### ✅ [SL-16](https://github.com/statline-iteso/statline-backend/issues/6) · CLI por deporte para los CronJob (`ingesta run <deporte>`)

**Sprint:** S2 · **Points:** 3 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] `ingesta run basquetbol|americano|futbol [--desde] [--hasta]`; por defecto ayer y hoy (UTC)
- [x] Código de salida ≠ 0 si la corrida falla, para que el Job quede como fallido

### ⏳ [SL-17](https://github.com/statline-iteso/statline-backend/issues/7) · Adaptador de Liga MX (api-football, liga 262)

**Sprint:** S4 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] `AdaptadorFutbol` implementa `AdaptadorDeporte` con jornada
- [ ] Métricas normalizadas válidas contra `futbol.schema.json`
- [ ] Pruebas con fixtures grabados

### ⏳ [SL-18](https://github.com/statline-iteso/statline-backend/issues/8) · Adaptador de NFL (api-american-football, liga 1)

**Sprint:** S4 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] `AdaptadorAmericano` implementa `AdaptadorDeporte` con semana como jornada
- [ ] Métricas por grupo (pase, carrera, recepción, defensa, pateo) válidas contra `americano.schema.json`
- [ ] Pruebas con fixtures grabados

### ✅ [SL-19](https://github.com/statline-iteso/statline-backend/issues/9) · Implementar AdaptadorDeporte para consumo de API-Sports en Python

**Sprint:** S2 · **Points:** 8 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] Interfaz `AdaptadorDeporte` con `obtener_partidos()`, `obtener_estadisticas()` y `normalizar()`
- [x] Cliente API-Sports con reintentos (429/5xx), backoff exponencial y tope de cuota diaria
- [x] `AdaptadorBasquetbol` (NBA, liga 12) de punta a punta con normalización en pandas

### ⏳ [SL-20](https://github.com/statline-iteso/statline-backend/issues/10) · Proveedores de respaldo: balldontlie.io (NBA) y TheSportsDB (NFL, Liga MX)

**Sprint:** S4 · **Points:** 6 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] Si API-Sports falla o agota la cuota, el ejecutor reintenta con el respaldo
- [ ] El proveedor usado queda en `ejecucion_ingesta.proveedor`

### ✅ [SL-21](https://github.com/statline-iteso/statline-backend/issues/11) · Dockerfile multi-etapa de ingesta (usuario no root)

**Sprint:** S2 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] Etapas deps → test → build → runtime; la etapa `test` corre ruff, mypy y pytest
- [x] Imagen final sin herramientas de build, usuario 10001, `ENTRYPOINT ["ingesta"]`

## E4 · API y modelo de datos

### ✅ [SL-22](https://github.com/statline-iteso/statline-backend/issues/12) · Esqueleto de la API (Node 20, Express, TypeScript) con /healthz, /readyz y /metrics

**Sprint:** S3 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] `createApp(deps)` como raíz de composición; `server.ts` con apagado ordenado en SIGTERM
- [x] /readyz consulta PostgreSQL; /metrics en formato Prometheus
- [x] Manejo central de errores con forma `{ error: { code, message } }`

### ✅ [SL-23](https://github.com/statline-iteso/statline-backend/issues/13) · Esquema Prisma de las 12 entidades con JSONB indexado (GIN)

**Sprint:** S2 · **Points:** 8 · **Priority:** Crítica · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] 12 entidades del dominio en `schema.prisma` con tablas snake_case
- [x] `metricas` JSONB con índice GIN `jsonb_path_ops`
- [x] Migración inicial y seed de las tres ligas

### ✅ [SL-24](https://github.com/statline-iteso/statline-backend/issues/14) · Autenticación JWT + bcrypt, roles y CRUD de usuarios

**Sprint:** S3 · **Points:** 5 · **Priority:** Crítica · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] POST /api/auth/login y POST /api/auth/refresh
- [x] Roles ADMIN, ANALISTA y USUARIO; solo ADMIN cambia roles
- [x] /api/usuarios con CRUD estándar; nunca expone el hash

### ✅ [SL-25](https://github.com/statline-iteso/statline-backend/issues/15) · CRUD de ligas y equipos con posiciones, calendario y forma

**Sprint:** S3 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] /api/ligas (?deporte=) con GET /:id/posiciones y GET /:id/calendario
- [x] /api/equipos con GET /:id/forma
- [x] Escrituras restringidas a ADMIN

### ✅ [SL-26](https://github.com/statline-iteso/statline-backend/issues/16) · CRUD de jugadores y partidos con boxscore

**Sprint:** S3 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] /api/jugadores (?q=, ?deporte=) y /api/partidos (?fecha=, ?jornada=)
- [x] GET /api/partidos/:id/boxscore separado por equipo

### ⏳ [SL-27](https://github.com/statline-iteso/statline-backend/issues/17) · Crear endpoints de agregación y comparación de atletas (/api/jugadores)

**Sprint:** S4 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] GET /api/jugadores/:id/promedios (por temporada, consulta JSONB)
- [ ] GET /api/jugadores/:id/tendencia (últimos N partidos)
- [ ] GET /api/jugadores/comparar?ids= (2 a 4 jugadores del mismo deporte)

### ⏳ [SL-28](https://github.com/statline-iteso/statline-backend/issues/18) · Endpoints de estadísticas y listas de seguimiento

**Sprint:** S4 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] /api/estadisticas (?jugadorId=) con CRUD estándar
- [ ] /api/listas: POST /:id/elementos y DELETE /:id/elementos/:ref; cada usuario ve solo sus listas

### ⏳ [SL-29](https://github.com/statline-iteso/statline-backend/issues/19) · Endpoints de pronósticos, proyecciones y modelos (proxy a predicciones)

**Sprint:** S4 · **Points:** 4 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] /api/pronosticos y /api/proyecciones (?jornada=, ?deporte=) con POST /generar y GET /precision
- [ ] /api/modelos con POST /:id/activar (uno activo por deporte y tipo) y POST /reentrenar

### ⏳ [SL-30](https://github.com/statline-iteso/statline-backend/issues/20) · Endpoints de alertas e ingestas

**Sprint:** S4 · **Points:** 3 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] /api/alertas con CRUD estándar por usuario
- [ ] /api/ingestas solo GET y DELETE, y POST /ejecutar restringido a ADMIN

### ⏳ [SL-31](https://github.com/statline-iteso/statline-backend/issues/21) · Caché y limitación de tasa con Redis

**Sprint:** S5 · **Points:** 3 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] Caché de lecturas frecuentes (posiciones, calendario) con invalidación tras la ingesta
- [ ] Rate limit por IP y por usuario; /readyz incluye Redis

## E5 · Servicio de predicciones

### ✅ [SL-32](https://github.com/statline-iteso/statline-backend/issues/22) · Esqueleto del servicio de predicciones (FastAPI) con probes y contrato

**Sprint:** S3 · **Points:** 3 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] /healthz, /readyz (PostgreSQL) y /metrics
- [x] Contrato de entrada validado con Pydantic; rutas pendientes responden 501

### ⏳ [SL-33](https://github.com/statline-iteso/statline-backend/issues/23) · Extracción de características desde PostgreSQL

**Sprint:** S4 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] Forma reciente, promedios móviles y localía por equipo
- [ ] Promedios móviles por jugador desde `metricas` JSONB

### ⏳ [SL-34](https://github.com/statline-iteso/statline-backend/issues/24) · Regresión logística para resultado de partido y marcador esperado

**Sprint:** S4 · **Points:** 8 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] Probabilidades local/empate/visita (empate solo en fútbol)
- [ ] Marcador esperado; comparación contra baseline (siempre gana local)

### ⏳ [SL-35](https://github.com/statline-iteso/statline-backend/issues/25) · Entrenar modelo de Gradient Boosting para proyección de métricas individuales

**Sprint:** S4 · **Points:** 8 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] Un modelo por métrica principal de cada deporte
- [ ] MAE validado contra baseline (promedio de los últimos 5 partidos)

### ⏳ [SL-36](https://github.com/statline-iteso/statline-backend/issues/26) · Registro de modelos en ModeloPrediccion (versionado y activación)

**Sprint:** S4 · **Points:** 5 · **Priority:** Alta · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] Artefactos joblib versionados; registro con métrica de error
- [ ] Solo un modelo activo por deporte y tipo

### ⏳ [SL-37](https://github.com/statline-iteso/statline-backend/issues/27) · Endpoints /generar que escriben PronosticoPartido y ProyeccionJugador

**Sprint:** S4 · **Points:** 4 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] POST /pronosticos/generar y /proyecciones/generar usan el modelo activo

### ⏳ [SL-38](https://github.com/statline-iteso/statline-backend/issues/28) · Endpoints de precisión y reentrenamiento

**Sprint:** S5 · **Points:** 3 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [ ] GET /precision compara pronósticos con resultados finales
- [ ] POST /modelos/reentrenar registra una versión nueva inactiva

### ✅ [SL-39](https://github.com/statline-iteso/statline-backend/issues/29) · Dockerfile multi-etapa de predicciones y cobertura con pytest

**Sprint:** S3 · **Points:** 2 · **Priority:** Media · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] Etapa `test` con ruff, mypy y pytest (cobertura ≥ 70 %); runtime no root

## E6 · Frontend

### ✅ [SL-40](https://github.com/statline-iteso/statline-frontend/issues/1) · Proyecto React 18 + Vite + TypeScript + TailwindCSS con layout y rutas

**Sprint:** S4 · **Points:** 3 · **Priority:** Alta · **Repo:** `statline-frontend`

**Acceptance criteria**

- [x] Vite, TypeScript strict, Tailwind, React Router con rutas lazy
- [x] Layout con navegación, página 404 y manejo de errores de ruta

### ✅ [SL-41](https://github.com/statline-iteso/statline-frontend/issues/2) · Cliente API, TanStack Query y sesión (login, refresh, rutas protegidas)

**Sprint:** S4 · **Points:** 5 · **Priority:** Crítica · **Repo:** `statline-frontend`

**Acceptance criteria**

- [x] Cliente tipado con renovación automática del access token
- [x] TanStack Query con reintentos e invalidación
- [x] Login, logout y `RequireAuth`

### ✅ [SL-42](https://github.com/statline-iteso/statline-frontend/issues/3) · Vistas de jugadores: búsqueda, filtro por deporte y detalle

**Sprint:** S4 · **Points:** 4 · **Priority:** Alta · **Repo:** `statline-frontend`

**Acceptance criteria**

- [x] Lista paginada con búsqueda (?q=) y filtro por deporte
- [x] Detalle del jugador con equipo y estatus

### ✅ [SL-43](https://github.com/statline-iteso/statline-frontend/issues/4) · Vistas de ligas y partidos: posiciones y calendario por fecha

**Sprint:** S4 · **Points:** 4 · **Priority:** Alta · **Repo:** `statline-frontend`

**Acceptance criteria**

- [x] Tabla de posiciones por liga
- [x] Partidos por fecha con marcador y estatus

### ⏳ [SL-44](https://github.com/statline-iteso/statline-frontend/issues/5) · Construir componentes visuales de boxscore con TailwindCSS y Recharts

**Sprint:** S4 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-frontend`

**Acceptance criteria**

- [ ] Tabla de boxscore por equipo con columnas según el deporte
- [ ] Gráfica de barras de líderes del partido (Recharts)

### ⏳ [SL-45](https://github.com/statline-iteso/statline-frontend/issues/6) · Comparación de jugadores y equipos

**Sprint:** S4 · **Points:** 4 · **Priority:** Media · **Repo:** `statline-frontend`

**Acceptance criteria**

- [ ] Selector de 2 a 4 jugadores y gráfica de radar con promedios

### ⏳ [SL-46](https://github.com/statline-iteso/statline-frontend/issues/7) · Vistas de pronósticos y proyecciones

**Sprint:** S5 · **Points:** 4 · **Priority:** Media · **Repo:** `statline-frontend`

**Acceptance criteria**

- [ ] Probabilidades por partido de la jornada y proyecciones por jugador

### ⏳ [SL-47](https://github.com/statline-iteso/statline-frontend/issues/8) · Listas de seguimiento y alertas

**Sprint:** S5 · **Points:** 4 · **Priority:** Media · **Repo:** `statline-frontend`

**Acceptance criteria**

- [ ] CRUD de listas y elementos; configuración de alertas por lesión, umbral o inicio

### ✅ [SL-48](https://github.com/statline-iteso/statline-frontend/issues/9) · Dockerfile con nginx y pruebas con Vitest (cobertura ≥ 70 %)

**Sprint:** S4 · **Points:** 3 · **Priority:** Media · **Repo:** `statline-frontend`

**Acceptance criteria**

- [x] Build multi-etapa servido por nginx no root, con fallback de SPA
- [x] Vitest + Testing Library con umbral de cobertura del 70 %

## E7 · Pipeline de CI/CD

### ✅ [SL-49](https://github.com/statline-iteso/statline-backend/issues/30) · Workflow ci.yml del backend (lint, tipos, pruebas, integración, imágenes)

**Sprint:** S3 · **Points:** 5 · **Priority:** Crítica · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] ESLint/Prettier/tsc y ruff/mypy; Jest y pytest con cobertura ≥ 70 %
- [x] Integración contra PostgreSQL efímero con las migraciones aplicadas
- [x] Build multi-etapa de api, predicciones e ingesta

### ✅ [SL-50](https://github.com/statline-iteso/statline-frontend/issues/10) · Workflow ci.yml del frontend

**Sprint:** S3 · **Points:** 3 · **Priority:** Alta · **Repo:** `statline-frontend`

**Acceptance criteria**

- [x] Lint, tipos, Vitest con cobertura, build y build de la imagen

### ✅ [SL-51](https://github.com/statline-iteso/statline-infra/issues/11) · Workflow ci.yml de infra: terraform fmt, validate, tflint y plan en el PR

**Sprint:** S3 · **Points:** 4 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] fmt, validate y tflint en cada push/PR
- [x] `helm lint` y kubeconform del chart
- [x] Job de `plan` que comenta el diff en el PR cuando existen las credenciales de Azure

### ✅ [SL-52](https://github.com/statline-iteso/statline-backend/issues/31) · Implementar workflow GitHub Actions con Trivy scanning y fail-gate

**Sprint:** S3 · **Points:** 5 · **Priority:** Crítica · **Repo:** `statline-backend`

**Acceptance criteria**

- [x] Trivy sobre cada imagen; falla ante hallazgos HIGH o CRITICAL
- [x] Las ramas `develop` y `main` exigen CI verde y una aprobación

### ⏳ [SL-53](https://github.com/statline-iteso/statline-infra/issues/12) · cd.yml, repositorio GitOps (chart Helm) y aplicaciones de Argo CD

**Sprint:** S5 · **Points:** 7 · **Priority:** Crítica · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] cd.yml publica statline/{web,api,predicciones,ingesta} en Docker Hub con SHA corto y SemVer
- [ ] El workflow actualiza la etiqueta en `gitops/values-<ambiente>.yaml`
- [ ] Chart Helm con Deployments, Services, Ingress, ConfigMaps y los 3 CronJob
- [ ] Aplicaciones de Argo CD para statline-staging (develop) y statline-prod (main)

## E8 · Observabilidad y resiliencia

### ⏳ [SL-54](https://github.com/statline-iteso/statline-infra/issues/13) · ServiceMonitors y dashboards de Grafana

**Sprint:** S5 · **Points:** 5 · **Priority:** Media · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] ServiceMonitor por servicio sobre /metrics
- [ ] Dashboard de latencia, errores e ingestas

### ⏳ [SL-55](https://github.com/statline-iteso/statline-infra/issues/14) · HorizontalPodAutoscaler de api y predicciones

**Sprint:** S5 · **Points:** 3 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] api 2–6 réplicas al 70 % de CPU; predicciones 1–4 al 75 %

### ⏳ [SL-56](https://github.com/statline-iteso/statline-infra/issues/15) · PodDisruptionBudget y NetworkPolicies

**Sprint:** S5 · **Points:** 4 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] default-deny por namespace y permisos explícitos
- [ ] PDB minAvailable 1 para web y api

### ⏳ [SL-57](https://github.com/statline-iteso/statline-infra/issues/16) · Pruebas de humo post-despliegue y rollback de Argo CD

**Sprint:** S5 · **Points:** 4 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] Job de humo contra /healthz y /readyz
- [ ] Rollback automático a la última revisión estable

### ⏳ [SL-58](https://github.com/statline-iteso/statline-infra/issues/17) · SecretProviderClass para montar secretos de Key Vault

**Sprint:** S5 · **Points:** 2 · **Priority:** Media · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] SecretProviderClass por ambiente y montaje en api, predicciones e ingesta

## E9 · Documentación y entrega

### ✅ [SL-59](https://github.com/statline-iteso/statline-infra/issues/18) · Documentación de arquitectura, modelo de datos y diseño de la API

**Sprint:** S3 · **Points:** 4 · **Priority:** Media · **Repo:** `statline-infra`

**Acceptance criteria**

- [x] docs/ARCHITECTURE.md, docs/modelo-datos.md y docs/api.md
- [x] Diagrama de la solución (Mermaid) y estrategia de ramas

### ⏳ [SL-60](https://github.com/statline-iteso/statline-infra/issues/19) · Evidencia de despliegue y runbook de operación

**Sprint:** S6 · **Points:** 4 · **Priority:** Media · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] Capturas de AKS, Argo CD, Grafana y pruebas de humo
- [ ] Runbook de alta y baja del ambiente

### ⏳ [SL-61](https://github.com/statline-iteso/statline-infra/issues/20) · Entrega final y defensa del proyecto

**Sprint:** S6 · **Points:** 4 · **Priority:** Alta · **Repo:** `statline-infra`

**Acceptance criteria**

- [ ] Release v1.0.0 en main
- [ ] Presentación y demo de punta a punta
