# Runbook

How to bring the StatLine environment up on Azure, run it, check it, roll it back and take it down. Each step names its command. Decisions behind the steps are in `docs/DECISIONS.md`.

Placeholders: `<env>` is `staging` or `prod`; `<dominio>` the environment host (`staging.<dominio>` for staging); `<kv>` the Key Vault name; `<ID>` a row from `argocd app history`; `<bump-sha>` the squash commit of a bump PR.

**Order for a fresh environment:** 1 (once) → 2 → 3 → 4 and 5 → 9 (evidence) → 8 at the end of the session.

**Rules:** `make apply`, `make destroy` and every `kubectl`/`az` command that changes something need the person running them to confirm the target first. `kubectl config current-context` must be `aks-statline` (or `k3d-*` locally) before any `kubectl` command here.

## 1. Before the first deploy (once)

Tools come from `mise install` (README). Then:

1. **Azure account and limits.**
   ```bash
   az login
   az account set --subscription "<Azure for Students>"
   az aks get-versions -l eastus2 -o table                  # is 1.30 offered? else the oldest supported minor
   az vm list-usage -l eastus2 -o table | grep -iE "Total Regional vCPUs|Standard BS Family"   # 4 × B2s = 8 vCPUs
   ```
   If 1.30 is gone, set `kubernetes_version` in `principal.auto.tfvars` and record it in DECISIONS (Known limitations).
2. **Docker Hub.** Create the repositories `statline/web`, `statline/api`, `statline/predicciones`, `statline/ingesta` and an access token with read and write.
3. **GitHub secrets.** Set them yourself, so the values never land in a file or a chat:
   ```bash
   gh secret set DOCKERHUB_USERNAME   -R statline-iteso/statline-backend    # and -R statline-iteso/statline-frontend
   gh secret set DOCKERHUB_TOKEN      -R statline-iteso/statline-backend    # and frontend
   gh secret set INFRA_DISPATCH_TOKEN -R statline-iteso/statline-backend    # and frontend; fine-grained PAT, contents: write on statline-infra
   gh secret set GITOPS_PR_TOKEN      -R statline-iteso/statline-infra      # fine-grained PAT, contents + pull-requests: write on statline-infra (D-36)
   ```
   `gh secret set` prompts for the value. The same PAT can serve both tokens if it has both permissions.
4. **Optional, CI `terraform plan` on PRs.** Without these the `plan` job is skipped and nothing else breaks. It needs an Entra app registration with a federated credential for `repo:statline-iteso/statline-infra:pull_request`, then `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, and `TFSTATE_RESOURCE_GROUP` + `TFSTATE_STORAGE_ACCOUNT` from step 2.1. The app needs to read the subscription, the state container, the Key Vault secrets and the cluster; expect to adjust its roles on the first run.

## 2. Bring the environment up

### 2.1 Terraform

```bash
make bootstrap                    # once per subscription: state storage account, writes terraform/principal/backend.hcl
terraform -chdir=terraform/bootstrap output           # resource_group_name, storage_account_name → TFSTATE_* secrets
cp terraform/principal/terraform.tfvars.example terraform/principal/principal.auto.tfvars
# edit: subscription_id; dominio only if a domain is decided (else nip.io, below)
make apply-aks                    # step 1: the AKS cluster alone (the kubernetes/helm providers need it)
make plan                         # step 2: everything else; read the summary
make apply                        # asks before applying (~15 min)
az aks get-credentials -g rg-statline -n aks-statline
kubectl config current-context    # must print aks-statline
```

Outputs used below: `terraform -chdir=terraform/principal output` (`key_vault_name`, `tenant_id`, `key_vault_csi_identity_client_id`, `ingress_public_ip`, `dns_name_servers`).

### 2.2 Secrets Terraform cannot know

Terraform creates every Key Vault secret; the API keys are placeholders (`ignore_changes`). Set the real values without leaving them in the shell history:

```bash
KV=$(terraform -chdir=terraform/principal output -raw key_vault_name)
read -rs KEY && az keyvault secret set --vault-name "$KV" -n api-sports-key --value "$KEY" -o none; unset KEY
read -rs KEY && az keyvault secret set --vault-name "$KV" -n balldontlie-api-key --value "$KEY" -o none; unset KEY   # optional
```

The admin password for the app (`admin@statline.local`) is generated per environment (D-37):

```bash
az keyvault secret show --vault-name "$KV" -n seed-admin-password-staging --query value -o tsv
```

### 2.3 Fill the GitOps placeholders (one PR into `develop`)

| File | Set |
|---|---|
| `gitops/charts/statline/values-staging.yaml`, `values-prod.yaml` | `ingress.host`: `staging.<dominio>` / `<dominio>`, or without a domain `staging.<ip>.nip.io` / `<ip>.nip.io` (`ingress_public_ip`); `secrets.csi.keyvaultName`, `tenantId`, `userAssignedIdentityID` (`key_vault_csi_identity_client_id`) |
| `gitops/plataforma/cluster-issuers.yaml` | the contact email (now `change-me@example.com`) |

With a domain, delegate it at the registrar to `dns_name_servers` first; Let's Encrypt needs the name to resolve. `values-prod.yaml` reaches `main` with the release (SL-61).

### 2.4 First images

The app repos publish on every merge to `develop`. To publish the current `develop` without a new commit:

```bash
gh workflow run cd.yml -R statline-iteso/statline-backend --ref develop
gh workflow run cd.yml -R statline-iteso/statline-frontend --ref develop
```

Each run builds, scans and pushes, then asks statline-infra for a bump. `cd.yml` in infra opens or updates the PR from `gitops/bump-staging`, and auto-merge merges it when CI passes (D-36). Check with `gh pr list -R statline-iteso/statline-infra --head gitops/bump-staging --state all`.

### 2.5 Argo CD

Terraform installs Argo CD in `plataforma`. Bootstrap the project and the app of apps once:

```bash
kubectl apply -f gitops/argocd/project.yaml -f gitops/argocd/root.yaml
kubectl -n plataforma get applications            # root, statline-staging, statline-prod, redis, plataforma-config
kubectl -n plataforma get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n plataforma port-forward svc/argo-cd-argocd-server 8080:80     # UI at http://localhost:8080, user admin
argocd login localhost:8080 --username admin --insecure --grpc-web        # for the argocd commands in sections 4 and 6
```

Expected until the release: `statline-prod` shows `ComparisonError … app path does not exist`, because `main` does not have the chart yet (SL-61). Staging syncs from `develop`. The api pods run `migrate` and then `seed` before serving (leagues and first ADMIN, D-37), and the sync ends with the smoke hook (section 4).

Grafana: `kubectl -n plataforma port-forward svc/kube-prometheus-stack-grafana 3000:80`, user `admin`, password from `terraform -chdir=terraform/principal output -raw grafana_admin_password`.

## 3. First data and models

Log in as the seeded admin and keep the token in a variable:

```bash
H=https://staging.<dominio>
read -rs PASS                     # seed-admin-password-staging (2.2)
TOKEN=$(curl -s "$H/api/auth/login" -H 'content-type: application/json' \
  -d "{\"email\":\"admin@statline.local\",\"password\":\"$PASS\"}" | jq -r .accessToken); unset PASS
```

**Ingest.** The CronJobs run on their schedule (`0 8 * * *` NBA, `0 8 * * 2` NFL, `0 8 * * 1,5` Liga MX). To run one now:

```bash
kubectl -n statline-staging create job ingesta-nba-$(date +%s) --from=cronjob/statline-staging-ingesta-basquetbol
kubectl -n statline-staging logs -f job/<that job>
```

Do this once per sport on the first deploy: the NFL, Liga MX and fallback mappings come from provider docs and have never seen a live response (backend D-24, D-25, D-27). A mapping error shows up as discarded lines or a failed `ejecucion_ingesta` row (`GET $H/api/ingestas`). Save the failing response as a fixture and fix the adapter.

**Train and generate.** Training needs finished games in the database. With real data:

```bash
for d in BASQUETBOL AMERICANO FUTBOL; do for t in RESULTADO_PARTIDO PROYECCION_JUGADOR; do
  curl -s -X POST "$H/api/modelos/reentrenar" -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
    -d "{\"deporte\":\"$d\",\"tipo\":\"$t\"}" | jq '{deporte, tipo, activado, motivo}'
done; done
for d in BASQUETBOL AMERICANO FUTBOL; do
  curl -s -X POST "$H/api/pronosticos/generar"  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d "{\"deporte\":\"$d\"}" | jq .generados
  curl -s -X POST "$H/api/proyecciones/generar" -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d "{\"deporte\":\"$d\"}" | jq .generados
done
```

A model is activated only if it beats its baseline (backend D-31): `activado: false` with a `motivo` is a valid answer. Training can outlast the api's 30 s proxy timeout (503) while predicciones still finishes; check `GET $H/api/modelos`.

**Without enough real games (demo only, staging only).** `ingesta seed-demo` writes synthetic games marked `demo` (backend D-29), enough for every model to activate. Run it as a one-off Job from the NBA CronJob spec, which already has the database secret:

```bash
kubectl -n statline-staging create job demo-seed --from=cronjob/statline-staging-ingesta-basquetbol --dry-run=client -o json \
  | jq '.spec.template.spec.containers[0].args = ["seed-demo","--confirmar"]' | kubectl apply -f -
kubectl -n statline-staging logs -f job/demo-seed
```

Then train and generate as above. Never run it in prod.

## 4. Post-deploy smoke tests

Every sync of `statline-staging` and `statline-prod` ends with the Job `<release>-smoke` (`statline-staging-smoke`, `statline-prod-smoke`). It is an Argo CD `PostSync` hook, and Helm runs it too on `make k3d-deploy`.

What it checks, from inside the namespace, with up to 10 attempts 6 s apart per check:

| Check | Must return |
|---|---|
| `http://<release>-web/healthz` | 200 |
| `http://<release>-api/healthz` | 200 |
| `http://<release>-api/readyz` | 200 (also checks Redis) |
| `http://<release>-predicciones/healthz` | 200 |
| `http://<release>-predicciones/readyz` | 200 |

The whole Job stops after 180 s. The smoke pod carries the label `statline.io/smoke: "true"`. The NetworkPolicies allow that label to reach web, api and predicciones. If a check fails for a new reason, look at the NetworkPolicies first.

**A failed check fails the sync.** The new pods keep serving traffic, because Argo CD does not roll back. Argo retries the sync twice (`retry.limit: 2`), then stops and leaves the Application in a failed operation state.

Find out what failed:

```bash
argocd app get statline-prod                       # operation phase, last sync result, hook status
kubectl -n statline-prod get job statline-prod-smoke
kubectl -n statline-prod logs job/statline-prod-smoke   # which URL, which status code
```

A successful Job is deleted by its hook policy, so the logs exist only after a failure. A failed Job stays until the next sync (`BeforeHookCreation`).

Run the same checks by hand:

```bash
make smoke ENV=staging                 # statline-staging, release statline-staging
make smoke ENV=prod                    # statline-prod, release statline-prod
make smoke ENV=staging RELEASE=statline   # k3d-deploy installs the release as "statline"
```

`make smoke` creates a throwaway pod with the curl image and the same script (`gitops/charts/statline/files/smoke-test.sh`). It refuses to run unless the current kubectl context starts with `k3d-` or `aks-statline`. Do not point it at any other cluster.

## 5. Public smoke checks (after a deploy, from outside)

```bash
scripts/smoke.sh https://<dominio>
```

It checks two things through the public Ingress:

- `https://<dominio>/healthz` returns 200. This is the web (nginx) health endpoint.
- `https://<dominio>/api/ligas` returns 401 without credentials. The Ingress routes `/api` to the api, and its reads require auth. A 401 proves that routing works. A 404 or 200 means the routing or the auth changed, so check with the backend owner.

CI can call it too. It uses `SMOKE_ATTEMPTS` (default 10) and `SMOKE_INTERVAL` (default 6 s).

## 6. Rollback

### 6.1 Decide

1. Confirm the release is bad, not the checks. Run `make smoke ENV=<env>` or `scripts/smoke.sh`, and read the smoke logs (section 4).
2. Note the bad image tag and the last good one: `argocd app history statline-prod`, and `git log -p -- gitops/charts/statline/values-prod.yaml`.
3. Remember the database is not rolled back. The previous image must still work with the migrated schema (D-12). If a migration removed or renamed something the previous image uses, a rollback is not safe. Fix forward instead.

### 6.2 Primary: revert the image-tag bump (GitOps)

The image tag lives in Git (`gitops/charts/statline/values-<env>.yaml`). `cd.yml` writes it through a bump PR from `gitops/bump-<env>` (D-36), which lands as one squash commit `ci(gitops): bump image tags (<env>)`. Reverting that commit puts the old tags back, and Argo CD syncs them.

Staging (branch `develop`):

```bash
git fetch origin
git switch -c fix/SL-<issue>-revert-staging-tags origin/develop
git log --oneline -5 -- gitops/charts/statline/values-staging.yaml   # find <bump-sha>
git revert --no-edit <bump-sha>
git push -u origin HEAD
gh pr create --base develop --title "fix(gitops): revert staging image tags" --body "Closes #<issue>"
```

Prod (branch `main`): the same with `origin/main`, a `hotfix/` branch and `values-prod.yaml`. If `<bump-sha>` is a release merge commit, use `git revert -m 1 --no-edit <bump-sha>`.

Both branches are protected, so the revert merges through its PR (CI green; staging auto-merges, prod needs a review). After a prod revert, back-merge `main` into `develop` so the next release does not bring the bad tag back. **A pending bump PR** (`gitops/bump-<env>`) still carries the bad tag: close it and delete the branch before the revert merges, or the next merge re-applies it.

Then Argo CD picks up the new revision. It polls about every 3 minutes. To not wait:

```bash
argocd app sync statline-staging      # or statline-prod
argocd app wait statline-prod --health --timeout 300
make smoke ENV=prod                   # or scripts/smoke.sh https://<dominio>
```

Do not revert the database. Migrations are forward only (D-12).

### 6.3 Stopgap: `argocd app rollback` (minutes, not a fix)

Use this only when the revert PR cannot merge soon and users are affected. Argo CD rolls the cluster back to an older revision from its history. It does not change Git, so Git still points at the bad tag.

Argo CD refuses a rollback while automated sync is on. Turn it off first:

```bash
argocd app set statline-prod --sync-policy none
argocd app history statline-prod                 # pick the ID of the last Succeeded revision
argocd app rollback statline-prod <ID>
make smoke ENV=prod
```

Then do 6.2 right away. **Only turn auto-sync back on after the revert is merged into `main`.** Before that, auto-sync re-applies the bad revision from Git:

```bash
argocd app set statline-prod --sync-policy automated --auto-prune --self-heal
```

Staging works the same way with `statline-staging`.

### 6.4 k3d

`make k3d-deploy` runs `helm upgrade --install`, and the smoke hook runs as a post-upgrade hook. A failed hook leaves the release failed, and Helm does not roll back by itself. Roll back with:

```bash
helm -n statline-staging history statline
helm -n statline-staging rollback statline <REVISION>
```

## 7. Argo CD retry behavior

Staging and prod use `syncPolicy.retry.limit: 2` with backoff from 10 s (factor 2, max 5 min). A failing hook therefore runs at most three times, not six (D-35). After the limit, Argo stops retrying and waits for a new commit or a manual sync. The platform Applications (redis, plataforma-config) keep `limit: 5`.

## 8. Tear down (end of every session)

`make destroy` removes the whole `principal` stack, the database included (D-16). The state storage account from `make bootstrap` stays, so the next `make apply` works without a new bootstrap.

1. **Keep the data, if it matters.** PostgreSQL is private and the namespaces are default-deny, so dump from a Job built from the NBA CronJob: it keeps the labels the PostgreSQL egress rule allows, the Key Vault volume and `DATABASE_URL`; only the image and the command change.
   ```bash
   ENV=staging   # or prod
   kubectl -n statline-$ENV create job pgdump --from=cronjob/statline-$ENV-ingesta-basquetbol --dry-run=client -o json \
     | jq '.spec.template.spec.containers[0] += {image: "postgres:16-alpine", command: ["sh","-c","pg_dump --no-owner --no-privileges \"$DATABASE_URL\""], args: null}' \
     | kubectl apply -f -
   kubectl -n statline-$ENV wait --for=condition=complete job/pgdump --timeout=300s
   kubectl -n statline-$ENV logs job/pgdump > statline_$ENV-$(date +%F).sql
   kubectl -n statline-$ENV delete job pgdump
   ```
   Restore after the next `make apply` (and after the api pods have migrated) the same way, with the file mounted from a ConfigMap or piped through `kubectl exec -i` into `psql "$DATABASE_URL"`. Dumps hold user emails and password hashes: keep them out of the repo.
2. **Destroy.**
   ```bash
   make destroy                      # shows the destroy plan, asks before running (~10 min)
   kubectl config delete-context aks-statline
   ```
3. Check the portal (or `az resource list -g rg-statline -o table`) shows nothing left but the state resource group.

## 9. Evidence for SL-60

Capture each item after a deploy, with the date visible, and put it in `docs/evidencia/` (PNG or text):

- [ ] `make apply` summary (`Apply complete! Resources: …`).
- [ ] `kubectl get nodes -o wide` and `kubectl get pods -A` (all Running or Completed).
- [ ] Argo CD UI: the five Applications, `statline-staging` Synced and Healthy, its resource tree.
- [ ] A smoke hook that passed (`argocd app get statline-staging` shows the hook) and `scripts/smoke.sh https://staging.<dominio>`.
- [ ] Grafana: the api dashboard with traffic, and the ingesta dashboard after one run.
- [ ] One ingestion per sport (`GET /api/ingestas`) and the forecasts screen with data.
- [ ] A rollback drill on staging (section 6.2) with the before and after tags.
- [ ] `make destroy` summary at the end.
