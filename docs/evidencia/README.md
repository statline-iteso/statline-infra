# Evidencia de despliegue (SL-60)

Lo que pide [RUNBOOK §9](../RUNBOOK.md#9-evidence-for-sl-60), por sesión. Las horas de los archivos están en UTC.

## 2026-11-23 · staging en AWS Learner Lab

Entorno: EKS 1.35 (2 × t3.medium), RDS PostgreSQL 16, `https://staging.52.71.150.91.nip.io`. Imágenes `pardosito/web:1d11fbc` y `pardosito/{api,predicciones,ingesta}:280774b` (infra #60).

| Punto de §9 | Estado | Archivo |
|---|---|---|
| Resumen de `make apply` | Pendiente: la salida del apply de esta sesión no se guardó; se captura en la siguiente reconstrucción | — |
| Nodos, pods y ExternalSecret | ✅ 2 nodos Ready (110 pods cada uno); todo Running o Completed salvo los Jobs de ingesta fallidos de abajo; `statline-secrets` SecretSynced | [cluster.txt](2026-11-23/cluster.txt) |
| Argo CD: Applications, staging Synced y Healthy | ✅ cinco Applications; `statline-staging` Synced y Healthy con su árbol de recursos. `root` aparecía OutOfSync por un campo por defecto en `plataforma-config` (corregido en infra #64); `statline-prod` espera el release | [argocd.txt](2026-11-23/argocd.txt), [argocd-applications.png](2026-11-23/argocd-applications.png), [argocd-staging-arbol.png](2026-11-23/argocd-staging-arbol.png) |
| Hook de smoke y `scripts/smoke.sh` | ✅ hook PostSync `statline-staging-smoke` Succeeded; `make smoke ENV=staging` y `scripts/smoke.sh` pasan con certificado de confianza (D-39) | [smoke.txt](2026-11-23/smoke.txt), [smoke-publico.txt](2026-11-23/smoke-publico.txt) |
| Grafana: dashboards de api e ingesta | ✅ StatLine · API con tráfico (peticiones por ruta, latencia, réplicas, HPA) y StatLine · Predicciones e ingesta (entrenamiento y generación, Jobs de ingesta fallidos por CronJob) | [grafana-api.png](2026-11-23/grafana-api.png), [grafana-predicciones-ingesta.png](2026-11-23/grafana-predicciones-ingesta.png) |
| Una ingesta por deporte y pantalla de pronósticos | ✅ Con el plan gratuito de API-Sports, el error de plan pasa al respaldo (backend #59) y staging tiene el respaldo activo (D-40). Corridas programadas con datos reales: NBA 17 partidos (balldontlie; sin estadísticas, backend #63), NFL 4 y Liga MX 4 (TheSportsDB, llave `123`). Los modelos se entrenan con `seed-demo` (los proveedores gratuitos no dan estadísticas de jugadores); los 6 superan su baseline. Pantalla de pronósticos con datos marcados como sintéticos | [ingesta.txt](2026-11-23/ingesta.txt), [ingesta-respaldo.txt](2026-11-23/ingesta-respaldo.txt), [ingesta-programada.txt](2026-11-23/ingesta-programada.txt), [modelos.txt](2026-11-23/modelos.txt), [pronosticos.png](2026-11-23/pronosticos.png) |
| Simulacro de rollback (§6.2) | ✅ Revert del bump #67 en el PR #68: api, predicciones e ingesta de `6a763e8` a `280774b`, unos 3 min de abrir el PR a Argo CD Synced; hook de smoke, `make smoke` y `scripts/smoke.sh` pasan; Degraded 40 s por el HPA mientras arrancaban los pods. Vuelta a `6a763e8` con el PR #69 | [rollback.txt](2026-11-23/rollback.txt) |
| Resumen de `make destroy` y costo de la sesión | ✅ `Destroy complete! Resources: 40 destroyed.`; costo del laboratorio: USD 3.1 de 50. Sin clúster, RDS, balanceadores ni instancias; queda solo la Elastic IP del bootstrap. El primer intento falló por finalizers huérfanos (corregido en infra #74) | [destroy.txt](2026-11-23/destroy.txt) |

Los modelos se entrenaron llamando a predicciones dentro del clúster (un pod de curl con la etiqueta `statline.io/smoke`), con las mismas peticiones que la api reenvía para un ADMIN, sin usar la contraseña del admin.
