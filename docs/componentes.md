# Componentes y sus métodos

Diagramas de clases de los cuatro componentes de StatLine, tomados del código en `develop` (v1.2.0). Los servicios usan interfaces y funciones fábrica más que herencia; cada diagrama muestra las interfaces que cruzan capas, sus implementaciones y los métodos públicos. El modelo de datos (tablas y relaciones) está en [modelo-datos.md](modelo-datos.md) y las rutas de la API en [api.md](api.md).

| Componente | Repo | Lenguaje | Responsabilidad |
|---|---|---|---|
| web | statline-frontend | React 18 · TypeScript | SPA: catálogo, boxscores, comparación, pronósticos, listas, alertas, usuarios |
| api | statline-backend `services/api` | Node 20 · Express · Prisma | REST `/api/*`, autenticación (Cognito o local), roles, caché, límites de peticiones |
| predicciones | statline-backend `services/predicciones` | Python 3.12 · FastAPI · scikit-learn | Entrena, versiona y activa modelos; genera pronósticos y proyecciones |
| ingesta | statline-backend `services/ingesta` | Python 3.12 · httpx · psycopg | CronJobs por deporte: descarga, normaliza, valida contra JSON Schema y guarda |

## api (Node · Express)

`createApp(deps)` es la raíz de composición: recibe todas las dependencias (interfaces) y monta los routers. `server.ts` pasa las implementaciones reales y las pruebas pasan dobles.

```mermaid
classDiagram
    direction LR
    class AppDeps {
        +PrismaClient prisma
        +TokenService tokens
        +Autenticador cognito
        +PrediccionesClient predicciones
        +LanzadorIngesta lanzador
        +MetricasValidator metricas
        +RedisHandle redis
        +Metrics metrics
    }
    class TokenService {
        <<interface>>
        +signAccess(claims) string
        +signRefresh(claims) string
        +verifyAccess(token) Claims
        +verifyRefresh(token) Claims
    }
    class Autenticador {
        <<interface>>
        +autenticar(token) Promise~Claims~
    }
    class VerificadorCognito {
        <<interface>>
        +verificar(token) Promise~IdentidadCognito~
    }
    class Claims {
        +string sub
        +Rol rol
    }
    class PrediccionesClient {
        <<interface>>
        +get(path, query) Promise~PrediccionesResponse~
        +post(path, body) Promise~PrediccionesResponse~
    }
    class LanzadorIngesta {
        <<interface>>
        +lanzar(deporte) Promise~job~
    }
    class LanzadorKubernetes
    class LanzadorDeshabilitado
    class MetricasValidator {
        <<interface>>
        +validar(deporte, metricas) ErrorMetrica[]
    }
    class CatalogCache {
        <<interface>>
        +read RequestHandler
        +invalidate RequestHandler
    }
    class RedisHandle {
        <<interface>>
        +client Redis
        +ping(timeoutMs) Promise
        +close() Promise
    }
    class Middleware {
        +requireAuth(autenticar) RequestHandler
        +requireRole(roles) RequestHandler
        +errorHandler()
    }
    class Routers {
        +authRouter() login, refresh
        +usuariosRouter() me, CRUD, rol
        +ligas/equipos/jugadores/partidosRouter()
        +estadisticasRouter() lote
        +listasRouter() propias
        +alertasRouter()
        +ingestasRouter() ejecutar
        +pronosticos/proyecciones/modelosRouter()
    }
    AppDeps --> TokenService
    AppDeps --> Autenticador
    AppDeps --> PrediccionesClient
    AppDeps --> LanzadorIngesta
    AppDeps --> MetricasValidator
    AppDeps --> RedisHandle
    Autenticador ..> VerificadorCognito : modo cognito
    Autenticador ..> TokenService : modo local
    Autenticador --> Claims
    LanzadorIngesta <|.. LanzadorKubernetes
    LanzadorIngesta <|.. LanzadorDeshabilitado
    CatalogCache --> RedisHandle
    Routers --> Middleware
    Routers --> CatalogCache
```

- **Autenticación:** `requireAuth` convierte el bearer en `Claims {sub, rol}`. En modo `cognito` el `Autenticador` verifica el ID token de Cognito (`aws-jwt-verify`) y liga o crea el `Usuario` (backend D-41); en modo `local` envuelve `TokenService.verifyAccess`.
- **Roles:** `requireRole("ADMIN")` protege escrituras del catálogo, ingestas, activación de modelos y la gestión de usuarios.
- **Datos:** Prisma (`schema.prisma`) es dueño del esquema; las migraciones corren en un initContainer.

## ingesta (Python)

Un adaptador por deporte implementa `AdaptadorDeporte`; `AdaptadorConRespaldo` cae al proveedor gratuito cuando API-Sports no responde o el plan no alcanza. `ejecutar()` recorre los días, valida cada línea contra `schemas/<deporte>.schema.json` y guarda con un `Repositorio`.

```mermaid
classDiagram
    direction LR
    class AdaptadorDeporte {
        <<abstract>>
        +Deporte deporte
        +str proveedor
        +str proveedor_liga_id
        +peticiones_usadas() int
        +proveedor_efectivo() str
        +partidos_del_dia(fecha) list~PartidoNorm~
        +lineas_del_partido(partido_id) list~EstadisticaNorm~
        #obtener_partidos(fecha)* list~dict~
        #obtener_estadisticas(partido_id)* list~dict~
        #normalizar(partidos)* list~PartidoNorm~
        #normalizar_estadisticas(partido_id, lineas)* list~EstadisticaNorm~
    }
    class AdaptadorBasquetbol
    class AdaptadorAmericano
    class AdaptadorFutbol
    class AdaptadorBalldontlie
    class AdaptadorTheSportsDB
    class AdaptadorConRespaldo {
        +AdaptadorConRespaldo(principal, respaldo)
    }
    class ClienteApiSports {
        +get(path, params) list~dict~
        +close()
    }
    class ClienteRespaldo {
        +get(path, params) dict
        +close()
    }
    class Repositorio {
        <<interface>>
        +liga_id(deporte, proveedor, liga) str
        +iniciar_ejecucion(deporte, proveedor) str
        +finalizar_ejecucion(id, exitosa, registros, peticiones, proveedor, error)
        +guardar_partido(liga_id, partido) str
        +guardar_estadistica(deporte, liga_id, partido_id, linea)
    }
    class RepositorioPostgres {
        +conectar(database_url)$ RepositorioPostgres
    }
    class Ejecutor {
        +ejecutar(adaptador, repo, desde, hasta, schemas_dir) ResultadoEjecucion
    }
    class ResultadoEjecucion {
        +str ejecucion_id
        +bool exitosa
        +int partidos
        +int estadisticas
        +int descartadas
        +str error
    }
    class PartidoNorm
    class EstadisticaNorm {
        +JugadorNorm jugador
        +dict metricas
    }
    AdaptadorDeporte <|-- AdaptadorBasquetbol
    AdaptadorDeporte <|-- AdaptadorAmericano
    AdaptadorDeporte <|-- AdaptadorFutbol
    AdaptadorDeporte <|-- AdaptadorBalldontlie
    AdaptadorDeporte <|-- AdaptadorTheSportsDB
    AdaptadorDeporte <|-- AdaptadorConRespaldo
    AdaptadorConRespaldo o-- AdaptadorDeporte
    AdaptadorBasquetbol --> ClienteApiSports
    AdaptadorAmericano --> ClienteApiSports
    AdaptadorFutbol --> ClienteApiSports
    AdaptadorBalldontlie --> ClienteRespaldo
    AdaptadorTheSportsDB --> ClienteRespaldo
    Repositorio <|.. RepositorioPostgres
    Ejecutor --> AdaptadorDeporte
    Ejecutor --> Repositorio
    Ejecutor --> ResultadoEjecucion
    AdaptadorDeporte --> PartidoNorm
    AdaptadorDeporte --> EstadisticaNorm
```

## predicciones (Python · FastAPI)

Dos tipos de modelo: `RESULTADO_PARTIDO` (regresión logística sobre la forma de los equipos, más Poisson para el marcador esperado) y `PROYECCION_JUGADOR` (gradient boosting por métrica). Cada entrenamiento se registra versionado en `ModeloPrediccion` y solo se activa si supera su baseline.

```mermaid
classDiagram
    direction LR
    class API_FastAPI {
        +POST /modelos/reentrenar
        +POST /modelos/{id}/activar
        +POST /pronosticos/generar
        +POST /proyecciones/generar
        +GET /precision
    }
    class Servicio {
        +reentrenar(conn, body) dict
        +activar(conn, modelo_id) dict
        +generar_pronosticos(conn, body, cache_dir) dict
        +generar_proyecciones(conn, body, cache_dir) dict
        +precision(conn, deporte, tipo) dict
    }
    class Registro {
        +entrenar_y_registrar(conn, deporte, tipo) dict
        +registrar(conn, resultado, sintetico) RegistroModelo
        +decidir_activacion(supera_baseline, metrica, metrica_activa) tuple
        +activar(conn, modelo_id)
        +cargar_activo(conn, deporte, tipo, cache_dir) ModeloCargado
        +serializar(bundle) bytes
    }
    class ResultadoEntrenamiento {
        +Deporte deporte
        +TipoInferencia tipo
        +bundle
        +str nombre_metrica
        +float metrica
        +float baseline
        +int n_train
        +int n_test
        +supera_baseline() bool
    }
    class BundleResultado {
        +clasificador LogisticRegression
        +goles_local PoissonRegressor
        +goles_visita PoissonRegressor
        +features tuple
        +clases tuple
        +int ventana
    }
    class BundleJugador {
        +modelos dict~objetivo, GradientBoosting~
        +objetivos tuple
        +features tuple
        +int ventana
    }
    class ModelosResultado {
        +entrenar_resultado(deporte, partidos) ResultadoEntrenamiento
        +predecir_resultado(bundle, features) DataFrame
    }
    class ModelosJugador {
        +entrenar_jugador(deporte, lineas) ResultadoEntrenamiento
        +predecir_jugador(bundle, features) DataFrame
    }
    class Features {
        +features_partidos(partidos, ventana) DataFrame
        +features_jugadores(historial, consultas, objetivos, ventana) DataFrame
    }
    class Datos {
        +cargar_partidos(conn, deporte) DataFrame
        +cargar_lineas(conn, deporte) DataFrame
        +reemplazar_pronosticos(conn, filas)
        +reemplazar_proyecciones(conn, filas)
    }
    API_FastAPI --> Servicio
    Servicio --> Registro
    Servicio --> Datos
    Registro --> ModelosResultado
    Registro --> ModelosJugador
    Registro --> ResultadoEntrenamiento
    ModelosResultado --> BundleResultado
    ModelosJugador --> BundleJugador
    ModelosResultado --> Features
    ModelosJugador --> Features
```

## web (React)

```mermaid
classDiagram
    direction LR
    class AuthProvider {
        +Usuario usuario
        +ApiClient api
        +ProveedorCognito cognito
        +login(email, password)
        +logout()
    }
    class ApiClient {
        <<interface>>
        +get(path, query) Promise
        +post(path, body) Promise
        +put(path, body) Promise
        +patch(path, body) Promise
        +delete(path) Promise
    }
    class TokenStore {
        <<interface>>
        +get() Tokens
        +set(tokens)
    }
    class ProveedorCognito {
        <<interface>>
        +iniciarSesion(email, password) idToken
        +idToken(forzar) idToken
        +cerrarSesion()
        +registrar(email, password, nombre)
        +confirmarRegistro(email, codigo)
        +pedirRecuperacion(email)
        +confirmarRecuperacion(email, codigo, nueva)
    }
    class Queries {
        +useLigas() useJugadores() usePartidos()
        +usePronosticos() useProyecciones() useModelos()
        +useListas() useAlertas() useUsuarios()
        +useApiMutation(fn, invalidate)
    }
    class Paginas {
        Login Registro Recuperar
        Ligas Partidos Boxscore Jugadores Comparar
        Pronosticos Listas Alertas Usuarios
    }
    AuthProvider --> ApiClient
    AuthProvider --> TokenStore
    AuthProvider ..> ProveedorCognito : si config.js trae pool
    Queries --> ApiClient
    Paginas --> Queries
    Paginas --> AuthProvider
```
