# Diseño de la API

Entregable 3. La API es `statline/api` (Node 20 + Express + Prisma) en [`statline-backend/services/api`](https://github.com/statline-iteso/statline-backend/tree/develop/services/api). El Ingress manda `/api/*` al Service `api`; el frontend nunca llama a proveedores externos.

**Estado:** ✅ implementado y probado · 🕓 pendiente (issue).

## Convenciones

- JSON en camelCase. Fechas ISO-8601 UTC.
- Autenticación: `Authorization: Bearer <accessToken>` (JWT HS256, 15 min). El refresh token dura 7 días.
- Listas paginadas: `?page=1&pageSize=20` (máx. 100) → `{ "data": [...], "total": 42, "page": 1, "pageSize": 20 }`.
- Errores: `{ "error": { "code": "NOT_FOUND", "message": "Liga no encontrado", "details": [...] } }`.

| HTTP | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDATION_ERROR` | cuerpo, query o id con forma inválida (`details` lista cada campo) |
| 401 | `UNAUTHORIZED` | sin token, token inválido o vencido, credenciales incorrectas |
| 403 | `FORBIDDEN` | el rol no alcanza (p. ej. escribir el catálogo sin ser ADMIN) |
| 404 | `NOT_FOUND` | el recurso no existe |
| 400 | `INVALID_REFERENCE` | el cuerpo apunta a un partido, jugador o equipo que no existe |
| 409 | `DUPLICATE` | viola una llave única (p. ej. email repetido) |
| 409 | `NO_ACTIVE_MODEL` | no hay modelo activo para ese deporte y tipo (generar, precisión) |
| 413 | `PAYLOAD_TOO_LARGE` | cuerpo JSON mayor a 1 MB |
| 422 | `INSUFFICIENT_DATA` | no hay datos suficientes para entrenar o generar |
| 429 | `RATE_LIMITED` | más de `RATE_LIMIT_PER_MIN` (300) peticiones por minuto por IP; login: `RATE_LIMIT_LOGIN_PER_MIN` (10) |
| 500 | `INTERNAL` | error no previsto (sin detalles internos en la respuesta) |
| 502 | `PREDICCIONES_RESPUESTA_INVALIDA` | el servicio de predicciones respondió algo inesperado |
| 503 | `PREDICCIONES_UNAVAILABLE` · `NOT_CONFIGURED` | predicciones no responde (timeout `PREDICCIONES_TIMEOUT_MS`) · lanzador de ingesta deshabilitado |

## Endpoints técnicos

| Método y ruta | Respuesta | Estado |
|---|---|---|
| `GET /healthz` | `200 {"status":"ok"}` (liveness, no toca la base) | ✅ |
| `GET /readyz` | `200 {"status":"ready","checks":{"db":"ok","redis":"ok"}}` · `503` si PostgreSQL (o Redis, cuando `REDIS_URL` está definido) no responde | ✅ |
| `GET /metrics` | Formato Prometheus: `statline_http_requests_total`, `statline_http_request_duration_seconds` y métricas de Node | ✅ |

## Componentes

Todos exponen `POST {base}`, `GET {base}`, `GET {base}/:id`, `PUT {base}/:id` y `DELETE {base}/:id`, salvo donde se indica.

| Componente | Ruta base | Filtros en `GET {base}` | Métodos adicionales | Permisos | Estado |
|---|---|---|---|---|---|
| Usuario | `/api/usuarios` | — | `POST /api/auth/login` · `POST /api/auth/refresh` | `POST` público (rol USUARIO); listar y borrar: ADMIN; ver y editar: el propio usuario o ADMIN; cambiar rol: ADMIN | ✅ |
| Liga | `/api/ligas` | `?deporte=` | `GET /:id/posiciones` · `GET /:id/calendario` | lectura: autenticado; escritura: ADMIN | ✅ |
| Equipo | `/api/equipos` | — | `GET /:id/forma` | lectura: autenticado; escritura: ADMIN | ✅ |
| Jugador | `/api/jugadores` | `?q=`, `?deporte=` | `GET /:id/promedios?ultimos=` · `GET /:id/tendencia?metrica=&n=` · `GET /comparar?ids=a,b[,c,d]` (2–4, mismo deporte) | lectura: autenticado; escritura: ADMIN | ✅ |
| Partido | `/api/partidos` | `?fecha=` (YYYY-MM-DD, día UTC), `?jornada=` | `GET /:id/boxscore` | lectura: autenticado; escritura: ADMIN | ✅ |
| EstadisticaJugadorPartido | `/api/estadisticas` | `?jugadorId=`, `?partidoId=` | `POST /lote` (≤ 500 líneas, todo o nada; `metricas` validado contra el JSON Schema del deporte) | lectura: autenticado; escritura: ADMIN | ✅ |
| ListaSeguimiento | `/api/listas` | — | `POST /:id/elementos` `{tipo, refId}` · `DELETE /:id/elementos/:refId` | dueño de la lista (otra lista da 404); ADMIN lee todas | ✅ |
| PronosticoPartido | `/api/pronosticos` | `?deporte=`, `?jornada=`, `?partidoId=` (el más reciente por partido) | `POST /generar` · `GET /precision?deporte=` | lectura: autenticado; generar: ADMIN/ANALISTA | ✅ |
| ProyeccionJugador | `/api/proyecciones` | `?deporte=`, `?jornada=`, `?jugadorId=`, `?partidoId=` | `POST /generar` · `GET /precision?deporte=` | lectura: autenticado; generar: ADMIN/ANALISTA | ✅ |
| ModeloPrediccion | `/api/modelos` | `?deporte=`, `?tipo=` | solo lectura; `POST /:id/activar` · `POST /reentrenar` (ADMIN) | lectura: autenticado; acciones: ADMIN | ✅ |
| Alerta | `/api/alertas` | — | — (`tipo`: `LESION`, `INICIO_PARTIDO`, `UMBRAL` con `condicion {metrica, operador, valor}`) | dueño; ADMIN lee todas | ✅ |
| EjecucionIngesta | `/api/ingestas` | `?deporte=`, `?estatus=` | solo `GET` y `DELETE`; `POST /ejecutar {deporte}` → 202 (crea un Job desde el CronJob; 503 si `INGESTA_LANZADOR=deshabilitado`) | ADMIN | ✅ |

## Ejemplos

### Login

```http
POST /api/auth/login
Content-Type: application/json

{ "email": "admin@statline.local", "password": "********" }
```

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs…",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs…",
  "usuario": { "id": "8c0f…", "email": "admin@statline.local", "nombre": "Administrador", "rol": "ADMIN" }
}
```

Email desconocido y contraseña incorrecta dan la misma respuesta (`401 Credenciales inválidas`), para no revelar qué correos existen.

### Posiciones de una liga

```http
GET /api/ligas/61cce148-…/posiciones
Authorization: Bearer …
```

```json
{
  "ligaId": "61cce148-…",
  "deporte": "FUTBOL",
  "temporada": "2026",
  "posiciones": [
    {
      "posicion": 1,
      "equipo": { "id": "4444…", "nombre": "América", "abreviatura": "AME" },
      "equipoId": "4444…",
      "jugados": 17, "ganados": 11, "empatados": 4, "perdidos": 2,
      "aFavor": 33, "enContra": 15, "diferencia": 18,
      "puntos": 37, "porcentaje": 0.765
    }
  ]
}
```

Fútbol ordena por puntos (3/1/0), diferencia y goles a favor; NBA y NFL por porcentaje de victorias (en la NFL un empate cuenta como media victoria).

### Boxscore

```http
GET /api/partidos/6666…/boxscore
```

```json
{
  "partido": { "id": "6666…", "estatus": "FINALIZADO", "marcadorLocal": 118, "marcadorVisita": 111, "local": {…}, "visita": {…} },
  "local":  [ { "jugador": { "nombre": "N. Jokic" }, "minutos": 36, "metricas": { "puntos": 31, "rebotes": 14, "asistencias": 11 } } ],
  "visita": [ … ]
}
```

## Servicio de predicciones (interno)

Solo accesible dentro del clúster; la API lo invoca en `PREDICCIONES_URL`.

| Método y ruta | Cuerpo | Estado |
|---|---|---|
| `GET /healthz` · `GET /readyz` · `GET /metrics` | — | ✅ |
| `POST /pronosticos/generar` | `{ "deporte": "BASQUETBOL", "jornada": 3, "partido_ids": [] }` | ✅ |
| `POST /proyecciones/generar` | `{ "deporte": "FUTBOL", "jornada": 17, "jugador_ids": [] }` | ✅ |
| `GET /precision?deporte=&tipo=` | — (accuracy y log-loss de pronósticos; MAE por métrica de proyecciones; solo cuentan los generados antes del partido) | ✅ |
| `POST /modelos/reentrenar` | `{ "deporte": "AMERICANO", "tipo": "RESULTADO_PARTIDO" }` (se activa solo si mejora al baseline y al modelo activo) | ✅ |
| `POST /modelos/{id}/activar` | — (override de ADMIN, sin la regla del baseline) | ✅ |

Los cuerpos de petición van en snake_case; las respuestas en camelCase, y la API las reenvía tal cual. Las métricas de NFL en proyecciones usan llaves con punto (`pase.yardas`).

## Por qué REST y no GraphQL

Las pantallas leen recursos bien delimitados (posiciones, calendario, boxscore, ficha de jugador) que encajan con rutas REST cacheables por URL en Redis (las lecturas del catálogo, TTL `CACHE_TTL_S` = 60 s, encabezado `X-Cache`). GraphQL añadiría un esquema y un servidor más sin resolver un problema que tengamos.
