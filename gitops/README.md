# GitOps

Everything the cluster runs for StatLine, rendered by Argo CD from this repo.

## Layout

```
gitops/
├── charts/
│   ├── statline/            environment chart: web, api, predicciones, ingesta CronJobs, Ingress, secrets, monitoring
│   │   ├── dashboards/              Grafana dashboards (JSON), loaded as ConfigMaps when monitoring is on
│   │   ├── values.yaml              documented defaults (not renderable alone: image tags are required)
│   │   ├── values-staging.yaml      statline-staging, follows develop
│   │   ├── values-prod.yaml         statline-prod, follows main
│   │   └── values-k3d.yaml          local only: fake secrets, dev Postgres, images tagged local
│   └── redis/               Redis 7.4 StatefulSet for plataforma (cache, no persistence by default)
├── argocd/
│   ├── project.yaml         AppProject statline (bootstrap by hand)
│   ├── root.yaml            app of apps: syncs apps/ (bootstrap by hand)
│   └── apps/                statline-staging, statline-prod, redis, plataforma-config
└── plataforma/              cluster-wide: cert-manager ClusterIssuers letsencrypt-staging and letsencrypt-prod
```

Image tags are `<component>.image.tag` in `values-staging.yaml` and `values-prod.yaml`. They are placeholders (`"0000000"`) until `cd.yml` writes real short SHAs.

## Render

```bash
make helm-lint        # helm lint --strict, every chart and environment values file
make helm-validate    # helm template | kubeconform -strict, monitoring off and on, plus the Argo CD and plataforma manifests
helm template statline gitops/charts/statline -f gitops/charts/statline/values-staging.yaml
```

`make lint` runs both.

## How Argo CD picks things up

1. Bootstrap once. Terraform (`modules/plataforma`) installs Argo CD in `plataforma`, so the AppProject and every Application live there too:
   ```bash
   kubectl apply -f gitops/argocd/project.yaml -f gitops/argocd/root.yaml
   ```
2. `root` watches `gitops/argocd/apps` on `develop`. It creates the four Applications.
3. Each Application syncs its path with automated prune and self-heal, retries with backoff, and never creates namespaces (`CreateNamespace=false`). The namespaces come from `make k3d-up` locally and from ops in Azure.
4. `statline-staging` tracks `develop` and `statline-prod` tracks `main`. A merge to `develop` changes staging. Prod changes arrive through `release/*` into `main`.

Before the first sync, fill the placeholders:
- `values-staging.yaml` and `values-prod.yaml`: the ingress host (`staging.<dominio>`, `<dominio>`), `secrets.csi.keyvaultName`, `tenantId`, `userAssignedIdentityID` (from `terraform/principal` outputs).
- `plataforma/cluster-issuers.yaml`: the contact email.

## Test on k3d

```bash
make k3d-up                                  # cluster, ingress-nginx on :8080, namespaces
# In each app repo: build with tag "local"
docker build -f services/api/Dockerfile -t statline/api:local .            # statline-backend
docker build -f services/predicciones/Dockerfile -t statline/predicciones:local .
docker build -f services/ingesta/Dockerfile -t statline/ingesta:local .
docker build -t statline/web:local .                                       # statline-frontend
for img in api predicciones ingesta; do k3d image import statline/$img:local -c statline; done
k3d image import statline/web:local -c statline
make k3d-deploy                              # redis (plataforma) + chart (statline-staging), refuses non-k3d contexts
curl http://statline.localhost:8080/            # web (SPA)
curl http://statline.localhost:8080/api/healthz # api, if the backend serves its routes under /api (confirm with the backend owner)
make k3d-down
```

The dev Postgres is ephemeral: `make k3d-deploy` with a fresh cluster runs the api migrations again. The `api` pod waits for it in its initContainer.

## Secrets

Staging and prod use `secrets.mode: csi`. The SecretProviderClass `statline-kv` syncs Key Vault into the Secret `statline-secrets`. Its keys are the env var names (`DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET`, `API_SPORTS_KEY`, `BALLDONTLIE_API_KEY`, `SEED_ADMIN_PASSWORD`), and the Key Vault names are in `secrets.csi.objects`. k3d uses `secrets.mode: plain` with fake values. Never put a real value in a values file.

`SEED_ADMIN_PASSWORD` reaches only the api `seed` initContainer, which creates the leagues and the first ADMIN after the migrations (D-37).

The synced Secret exists only while a pod mounts the CSI volume. Every pod that reads it (including the api migrate initContainer and the CronJobs) mounts the volume; kubelet mounts volumes before it resolves container env, so there is no deadlock. `BALLDONTLIE_API_KEY` is `optional` in the pod spec, but its Key Vault object must exist. `api.ingestaLanzador: kubernetes` adds the Role and RoleBinding for on-demand ingestion Jobs; `ingesta.config.fallbackHabilitado` stays `"false"` in staging and prod.

## Not here yet

HPA, PodDisruptionBudgets and NetworkPolicies are built (SL-55, SL-56; see `docs/DECISIONS.md` D-31 and `docs/ARCHITECTURE.md` 5.1), and so are ServiceMonitors (SL-54, below). Post-deploy smoke tests are in `templates/smoke-test.yaml` (see `docs/RUNBOOK.md`). A failed smoke test does not roll back; `make smoke ENV=staging` runs the same checks by hand against k3d or AKS.

## Monitoring

`monitoring.enabled` (true in staging and prod, false in k3d) renders two ServiceMonitors (api, predicciones), the `<release>-alerts` PrometheusRule and two Grafana dashboard ConfigMaps. Thresholds and the extra labels are under `monitoring` in `values.yaml`. The dashboards read `dashboards/*.json`; they are validated with `python3 -m json.tool`. Architecture and metric names: ARCHITECTURE section 4.5.
