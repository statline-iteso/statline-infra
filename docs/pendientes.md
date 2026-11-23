# Pendientes para la entrega final

Entregable 6. **Juan Pablo** González (backend, frontend, cimientos) e **Ian** Rodríguez (infraestructura, predicciones, despliegue). Todo lo del [diagrama](solucion.png) está implementado; esta lista es lo que falta para la entrega. Cada punto tiene su issue en el [tablero](https://github.com/orgs/statline-iteso/projects) y en [BACKLOG.md](BACKLOG.md).

**Avance:** 60 de 61 issues · 273 de 277 puntos (99 %). El código está completo y fusionado en `develop` de los tres repos. Como se negaron los créditos de Azure, la infraestructura se movió a AWS Learner Lab (EKS, RDS, SSM; DECISIONS D-38, issue #50, cerrado). Staging se desplegó y se verificó el 2026-11-22 y el 2026-11-23: CD automático de punta a punta, pruebas de humo, ingesta real por deporte, simulacro de rollback y `make destroy`. La evidencia está en [evidencia/](evidencia/README.md) (SL-60, cerrado). Costo del laboratorio hasta el 2026-11-23: USD 3.1 de 50.

## Lo que falta

| # | Pendiente | Issue | Pts |
|---|---|---|---|
| 1 | Release `v1.0.0`: PRs `develop → main` en los tres repos (los revisa Juan Pablo), etiqueta y notas; despliegue de prod; presentación y demo de punta a punta | SL-61 | 4 |
| 2 | Resumen de `make apply` para la evidencia de SL-60: se captura en la siguiente reconstrucción del ambiente | SL-60 | — |

## Decisiones que faltan al desplegar prod

- Respaldo en prod: decidido, activo como en staging (D-41).
- `networkPolicies.kubeApiCidr` solo si se usa `api.ingestaLanzador: kubernetes`.

## Configuración en GitHub y AWS (lista)

- **Secrets de CI (infra):** `make creds` guarda las llaves del lab como `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`. Expiran con cada sesión; cuando expiran, el job `plan` se salta con un aviso.
- **Secrets de CD (backend y frontend):** `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `INFRA_DISPATCH_TOKEN` y la variable `DOCKERHUB_NAMESPACE=pardosito`. Las imágenes van a `pardosito/{web,api,predicciones,ingesta}`.
- **Token del bump en infra:** `GITOPS_PR_TOKEN`, un PAT fino aprobado por la organización (`contents` y `pull-requests` de escritura sobre `statline-infra`). Verificado: cada merge en una app abre y fusiona su bump PR de staging sin intervención (D-36).
- **Llaves de proveedores en SSM:** `/statline/comun/api-sports-key` y `/statline/comun/balldontlie-api-key` con valores reales. TheSportsDB usa su llave pública `123` (la `3` se retiró).
- **EKS 1.35:** en soporte estándar al 2026-11-21 (D-38). Si sale del soporte estándar, cambiar `kubernetes_version` y registrarlo en DECISIONS.

## Riesgos y plan B

| Riesgo | Impacto | Plan B |
|---|---|---|
| Dependencia de la API externa | Alto | El plan gratuito de API-Sports solo cubre 2022–2024; un error de plan cambia la corrida al respaldo (backend D-38). Staging recibe partidos reales de balldontlie y TheSportsDB, sin estadísticas de jugadores (backend D-39). Los modelos se entrenan con `ingesta seed-demo` |
| Lab: fin de sesión con el ambiente arriba | Alto | Al terminar la sesión el lab detiene y reemplaza los nodos; si no se reinicia pronto, no se vuelven a unir al clúster y todo sigue cobrando. `make destroy` antes de que acabe el tiempo; si ya pasó, `make creds` y reiniciar los nodos (RUNBOOK §8) |
| `make destroy` atorado | Medio | `scripts/vaciar-gitops.sh` borra las Applications y los ExternalSecrets antes de los charts; si un uninstall se atora igual, RUNBOOK §8 explica cómo quitar los finalizers |
| Agotamiento del presupuesto del lab (USD 50) | Crítico | 2 nodos t3.medium y RDS db.t3.micro (~USD 0.31/h), sin NAT gateway, `make destroy` al terminar cada sesión; revisar el gasto del lab en cada sesión |
| Restricciones ocultas del lab | Alto | El lab no deja leer sus políticas: un `AccessDenied` aparece hasta el apply. Cada uno se documenta en D-38 con su solución |
| Precisión pobre de los modelos | Medio | Siempre contra un baseline, versionado en `ModeloPrediccion`; solo se activa si mejora (backend D-31) |
