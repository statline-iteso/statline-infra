# Evidencia de despliegue (SL-60)

Lo que pide [RUNBOOK §9](../RUNBOOK.md#9-evidence-for-sl-60), por sesión. Las horas de los archivos están en UTC.

## 2026-11-23 · staging en AWS Learner Lab

Entorno: EKS 1.35 (2 × t3.medium), RDS PostgreSQL 16, `https://staging.52.71.150.91.nip.io`. Imágenes `pardosito/web:1d11fbc` y `pardosito/{api,predicciones,ingesta}:280774b` (infra #60).

| Punto de §9 | Estado | Archivo |
|---|---|---|
| Resumen de `make apply` | Pendiente: se capturará en la siguiente reconstrucción (la de esta sesión no se guardó) | — |
| Nodos, pods y ExternalSecret | ✅ 2 nodos Ready (110 pods cada uno); todo Running o Completed salvo los Jobs de ingesta fallidos de abajo; `statline-secrets` SecretSynced | [cluster.txt](2026-11-23/cluster.txt) |
| Argo CD: Applications, staging Synced y Healthy | ✅ en texto; falta la captura de la UI con el árbol de recursos | [argocd.txt](2026-11-23/argocd.txt) |
| Hook de smoke y `scripts/smoke.sh` | ✅ hook PostSync `statline-staging-smoke` Succeeded; `make smoke ENV=staging` y `scripts/smoke.sh` pasan con certificado de confianza (D-39) | [smoke.txt](2026-11-23/smoke.txt), [smoke-publico.txt](2026-11-23/smoke-publico.txt) |
| Grafana: dashboards de api e ingesta | Pendiente (captura de la UI) | — |
| Una ingesta por deporte y pantalla de pronósticos | ⚠ Las ingestas reales fallan por el plan gratuito de API-Sports (DECISIONS, limitaciones). Datos de `seed-demo` (sintéticos, solo staging); los 6 modelos superan su baseline y se activan; pronósticos y proyecciones generados. Falta la captura de la pantalla | [ingesta.txt](2026-11-23/ingesta.txt), [modelos.txt](2026-11-23/modelos.txt) |
| Simulacro de rollback (§6.2) | Pendiente: necesita dos etiquetas buenas; staging solo ha tenido una (la anterior era `0000000`). Se hace tras el siguiente merge en backend o frontend | — |
| Resumen de `make destroy` y costo de la sesión | Pendiente (al cerrar la sesión) | — |

Los modelos se entrenaron llamando a predicciones dentro del clúster (un pod de curl con la etiqueta `statline.io/smoke`), con las mismas peticiones que la api reenvía para un ADMIN, sin usar la contraseña del admin.
