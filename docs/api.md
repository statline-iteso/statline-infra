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
| 409 | `DUPLICATE` | viola una llave única (p. ej. email repetido) |
| 500 | `INTERNAL` | error no previsto (sin detalles internos en la respuesta) |

## Endpoints técnicos

| Método y ruta | Respuesta | Estado |
|---|---|---|
| `GET /healthz` | `200 {"status":"ok"}` (liveness, no toca la base) | ✅ |
| `GET /readyz` | `200 {"status":"ready","checks":{"db":"ok"}}` · `503` si PostgreSQL no responde | ✅ |
| `GET /metrics` | Formato Prometheus: `statline_http_requests_total`, `statline_http_request_duration_seconds` y métricas de Node | ✅ |

## Componentes

Todos exponen `POST {base}`, `GET {base}`, `GET {base}/:id`, `PUT {base}/:id` y `DELETE {base}/:id`, salvo donde se indica.

| Componente | Ruta base | Filtros en `GET {base}` | Métodos adicionales | Permisos | Estado |
|---|---|---|---|---|---|
| Usuario | `/api/usuarios` | — | `POST /api/auth/login` · `POST /api/auth/refresh` | `POST` público (rol USUARIO); listar y borrar: ADMIN; ver y editar: el propio usuario o ADMIN; cambiar rol: ADMIN | ✅ |
| Liga | `/api/ligas` | `?deporte=` | `GET /:id/posiciones` · `GET /:id/calendario` | lectura: autenticado; escritura: ADMIN | ✅ |
| Equipo | `/api/equipos` | — | `GET /:id/forma` | lectura: autenticado; escritura: ADMIN | ✅ |
| Jugador | `/api/jugadores` | `?q=`, `?deporte=` | `GET /:id/promedios` · `GET /:id/tendencia` · `GET /comparar?ids=` | lectura: autenticado; escritura: ADMIN | ✅ CRUD · 🕓 extras (SL-27) |
| Partido | `/api/partidos` | `?fecha=` (YYYY-MM-DD, día UTC), `?jornada=` | `GET /:id/boxscore` | lectura: autenticado; escritura: ADMIN | ✅ |
| EstadisticaJugadorPartido | `/api/estadisticas` | `?jugadorId=` | — | lectura: autenticado; escritura: ADMIN | 🕓 SL-28 |
| ListaSeguimiento | `/api/listas` | — | `POST /:id/elementos` · `DELETE /:id/elementos/:ref` | dueño de la lista | 🕓 SL-28 |
| PronosticoPartido | `/api/pronosticos` | `?jornada=`, `?deporte=` | `POST /generar` · `GET /precision` | lectura: autenticado; generar: ADMIN/ANALISTA | 🕓 SL-29 |
| ProyeccionJugador | `/api/proyecciones` | `?jornada=` | `POST /generar` · `GET /precision` | lectura: autenticado; generar: ADMIN/ANALISTA | 🕓 SL-29 |
| ModeloPrediccion | `/api/modelos` | `?deporte=`, `?tipo=` | `POST /:id/activar` · `POST /reentrenar` | ADMIN | 🕓 SL-29 |
| Alerta | `/api/alertas` | — | — | dueño | 🕓 SL-30 |
| EjecucionIngesta | `/api/ingestas` | — | solo `GET` y `DELETE`; `POST /ejecutar` (ADMIN) | ADMIN | 🕓 SL-30 |

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
| `POST /pronosticos/generar` | `{ "deporte": "BASQUETBOL", "jornada": 3, "partido_ids": [] }` | 🕓 501 hasta SL-34/37 |
| `POST /proyecciones/generar` | `{ "deporte": "FUTBOL", "jornada": 17, "jugador_ids": [] }` | 🕓 501 hasta SL-35/37 |
| `POST /modelos/reentrenar` | `{ "deporte": "AMERICANO", "tipo": "RESULTADO_PARTIDO" }` | 🕓 501 hasta SL-36/38 |

## Por qué REST y no GraphQL

Las pantallas leen recursos bien delimitados (posiciones, calendario, boxscore, ficha de jugador) que encajan con rutas REST cacheables por URL en Redis (SL-31). GraphQL añadiría un esquema y un servidor más sin resolver un problema que tengamos.
