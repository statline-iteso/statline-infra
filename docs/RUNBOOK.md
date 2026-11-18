# Runbook

Operational procedures for the StatLine cluster. Sections are short and each one names its command. SL-60 extends this file (alerts, incident handling). Decisions behind these steps are in `docs/DECISIONS.md` (D-21 to D-23).

Replace the placeholders before use: `<dominio>` is the environment host, `<ID>` a row from `argocd app history`, `<bump-sha>` the commit where `cd.yml` changed the image tag.

## 1. Post-deploy smoke tests

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

## 2. Public smoke checks (after a deploy, from outside)

```bash
scripts/smoke.sh https://<dominio>
```

It checks two things through the public Ingress:

- `https://<dominio>/healthz` returns 200. This is the web (nginx) health endpoint.
- `https://<dominio>/api/ligas` returns 401 without credentials. The Ingress routes `/api` to the api, and its reads require auth. A 401 proves that routing works. A 404 or 200 means the routing or the auth changed, so check with the backend owner.

CI can call it too. It uses `SMOKE_ATTEMPTS` (default 10) and `SMOKE_INTERVAL` (default 6 s).

## 3. Rollback

### 3.1 Decide

1. Confirm the release is bad, not the checks. Run `make smoke ENV=<env>` or `scripts/smoke.sh`, and read the smoke logs (section 1).
2. Note the bad image tag and the last good one: `argocd app history statline-prod`, and `git log -p -- gitops/charts/statline/values-prod.yaml`.
3. Remember the database is not rolled back. The previous image must still work with the migrated schema (D-12). If a migration removed or renamed something the previous image uses, a rollback is not safe. Fix forward instead.

### 3.2 Primary: revert the image-tag bump (GitOps)

The image tag lives in Git (`gitops/charts/statline/values-<env>.yaml`, written by `cd.yml`). Reverting the commit puts the old tag back, and Argo CD syncs it.

Staging (branch `develop`):

```bash
cd <repo>
git fetch origin
git switch -c fix/SL-<issue>-revert-web-tag origin/develop
git log --oneline -5 -- gitops/charts/statline/values-staging.yaml   # find <bump-sha>
git revert --no-edit <bump-sha>
git push -u origin HEAD
gh pr create --base develop --title "fix(gitops): revert staging image tag" --body "Closes #<issue>"
```

Prod (branch `main`), the same with `origin/main` and the prod values file:

```bash
git fetch origin
git switch -c hotfix/SL-<issue>-revert-prod-tag origin/main
git log --oneline -5 -- gitops/charts/statline/values-prod.yaml
git revert --no-edit <bump-sha>        # if <bump-sha> is a release merge commit: git revert -m 1 --no-edit <bump-sha>
git push -u origin HEAD
gh pr create --base main --title "fix(gitops): revert prod image tag" --body "Closes #<issue>"
```

Both branches are protected: merge through the PR (CI green, one approval). After the prod PR merges, back-merge `main` into `develop` so the next release does not bring the bad tag back.

Then Argo CD picks up the new revision. It polls about every 3 minutes. To not wait:

```bash
argocd app sync statline-staging      # or statline-prod
argocd app wait statline-prod --health --timeout 300
make smoke ENV=prod                   # or scripts/smoke.sh https://<dominio>
```

Do not revert the database. Migrations are forward only (D-12).

### 3.3 Stopgap: `argocd app rollback` (minutes, not a fix)

Use this only when the revert PR cannot merge soon and users are affected. Argo CD rolls the cluster back to an older revision from its history. It does not change Git, so Git still points at the bad tag.

Argo CD refuses a rollback while automated sync is on. Turn it off first:

```bash
argocd app set statline-prod --sync-policy none
argocd app history statline-prod                 # pick the ID of the last Succeeded revision
argocd app rollback statline-prod <ID>
make smoke ENV=prod
```

Then do 3.2 right away. **Only turn auto-sync back on after the revert is merged into `main`.** Before that, auto-sync re-applies the bad revision from Git:

```bash
argocd app set statline-prod --sync-policy automated --auto-prune --self-heal
```

Staging works the same way with `statline-staging`.

### 3.4 k3d

`make k3d-deploy` runs `helm upgrade --install`, and the smoke hook runs as a post-upgrade hook. A failed hook leaves the release failed, and Helm does not roll back by itself. Roll back with:

```bash
helm -n statline-staging history statline
helm -n statline-staging rollback statline <REVISION>
```

## 4. Argo CD retry behavior

Staging and prod use `syncPolicy.retry.limit: 2` with backoff from 10 s (factor 2, max 5 min). A failing hook therefore runs at most three times, not six (D-23). After the limit, Argo stops retrying and waits for a new commit or a manual sync. The platform Applications (redis, plataforma-config) keep `limit: 5`.
