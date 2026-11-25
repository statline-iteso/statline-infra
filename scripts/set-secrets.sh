#!/usr/bin/env bash
# Sets the SSM parameters Terraform cannot know: the API keys and the Sentry DSNs (D-43), and the
# password of the Cognito admin when the pools exist (D-47). Terraform
# creates them with the `set-me` placeholder and `make destroy` deletes them, so every lab session
# needs them again. `make apply` runs this at the end; `make secrets` runs it alone.
#
# Values come from the macOS login Keychain (service statline/<name>). A value missing there is
# asked for once (hidden input) and saved, so later sessions need no typing. Without the Keychain
# (Linux) it asks every time. ASK=1 asks again and replaces the saved values (rotating a key).
# Enter on an empty prompt skips that parameter; for the optional one it is remembered (saved as "-").
#
# Then, if the cluster is up, it forces External Secrets to sync and restarts the Deployments of
# each environment whose values changed (pods read their env at start). Uses a throwaway
# kubeconfig, never the default context.
set -euo pipefail

region=${AWS_REGION:-us-east-1}
cluster=${CLUSTER_NAME:-statline}

# name | kind (key: any value; opt: optional key; dsn: must start with https://) | label
params=(
  "api-sports-key|key|API-Sports key (api-sports.io dashboard)"
  "balldontlie-api-key|opt|balldontlie API key (optional, Enter to skip)"
  "sentry-dsn-api|dsn|Sentry DSN of statline-api"
  "sentry-dsn-predicciones|dsn|Sentry DSN of statline-predicciones"
  "sentry-dsn-ingesta|dsn|Sentry DSN of statline-ingesta"
  "sentry-dsn-web|dsn|Sentry DSN of statline-web"
)

have_keychain=false
command -v security >/dev/null && have_keychain=true
interactive=false
[[ -t 0 ]] && interactive=true

keychain_get() { security find-generic-password -s "statline/$1" -a statline -w 2>/dev/null; }
keychain_put() { security add-generic-password -U -s "statline/$1" -a statline -l "StatLine $1" -w "$2"; }
ssm_get() {
  aws ssm get-parameter --region "$region" --with-decryption --name "/statline/comun/$1" \
    --query Parameter.Value --output text 2>/dev/null
}

if ! aws ssm get-parameter --region "$region" --name /statline/comun/api-sports-key >/dev/null 2>&1; then
  echo "error: /statline/comun/* does not exist yet; run make apply first (Terraform owns the parameters)" >&2
  exit 1
fi

changed=0
for entry in "${params[@]}"; do
  IFS='|' read -r name kind label <<<"$entry"
  value=""
  if $have_keychain && [[ "${ASK:-}" != 1 ]]; then
    value=$(keychain_get "$name" || true)
  fi
  if [[ "$value" == - ]]; then
    echo "skip  $name (left out; ASK=1 to set it)" >&2
    continue
  fi
  if [[ -z "$value" ]]; then
    if ! $interactive; then
      echo "skip  $name: not in the Keychain and no terminal to ask" >&2
      continue
    fi
    read -rsp "$label: " value </dev/tty
    echo >&2
    if [[ -z "$value" ]]; then
      echo "skip  $name" >&2
      if [[ "$kind" == opt ]] && $have_keychain; then keychain_put "$name" -; fi
      continue
    fi
    if [[ "$kind" == dsn && "$value" != https://* ]]; then
      echo "skip  $name: a DSN starts with https:// (Sentry → project → Client Keys)" >&2
      continue
    fi
    if $have_keychain; then
      keychain_put "$name" "$value"
      echo "saved $name in the Keychain (statline/$name)" >&2
    fi
  fi
  current=$(ssm_get "$name" || true)
  if [[ "$current" == "$value" ]]; then
    echo "ok    $name (already set)" >&2
    continue
  fi
  # --value is visible in ps for the moment the command runs (RUNBOOK 2.2).
  aws ssm put-parameter --region "$region" --overwrite --type SecureString \
    --name "/statline/comun/$name" --value "$value" >/dev/null
  echo "set   $name" >&2
  changed=$((changed + 1))
done
unset value current

# Cognito admin (D-47): Terraform creates admin@statline.local in each pool with no password; this
# sets it, permanent, from the Keychain (statline/admin-password). Nothing to do without the pools
# (cognito_enabled false). No pod restart needed: Cognito checks it at sign-in.
admin_email=${ADMIN_EMAIL:-admin@statline.local}
pools=()
for env in staging prod; do
  if pool=$(aws ssm get-parameter --region "$region" --name "/statline/$env/cognito-user-pool-id"     --query Parameter.Value --output text 2>/dev/null); then
    pools+=("$env:$pool")
  fi
done
if ((${#pools[@]} > 0)); then
  pw=""
  if $have_keychain && [[ "${ASK:-}" != 1 ]]; then pw=$(keychain_get admin-password || true); fi
  if [[ -z "$pw" ]] && $interactive; then
    read -rsp "Password of the Cognito admin $admin_email (6+ characters): " pw </dev/tty
    echo >&2
    if ((${#pw} < 6)); then
      echo "skip  admin-password: Cognito needs at least 6 characters" >&2
      pw=""
    elif $have_keychain; then
      keychain_put admin-password "$pw"
      echo "saved admin-password in the Keychain (statline/admin-password)" >&2
    fi
  fi
  if [[ -z "$pw" ]]; then
    echo "skip  admin-password: not in the Keychain and not entered" >&2
  else
    for entry in "${pools[@]}"; do
      env=${entry%%:*}
      # --password is visible in ps for the moment the command runs, as with put-parameter above.
      if aws cognito-idp admin-set-user-password --region "$region" --user-pool-id "${entry#*:}"         --username "$admin_email" --password "$pw" --permanent >/dev/null; then
        echo "set   admin password in the $env pool" >&2
      else
        echo "warning: could not set the admin password in the $env pool" >&2
      fi
    done
  fi
  unset pw
fi

if ((changed == 0)); then
  echo "Nothing changed in SSM." >&2
  exit 0
fi

if ! aws eks describe-cluster --name "$cluster" --region "$region" >/dev/null 2>&1; then
  echo "$changed parameter(s) set; no cluster yet, the pods will read them when they start." >&2
  exit 0
fi
kc=$(mktemp)
trap 'rm -f "$kc"' EXIT
aws eks update-kubeconfig --name "$cluster" --region "$region" --kubeconfig "$kc" >/dev/null
k() { kubectl --kubeconfig "$kc" "$@"; }

for ns in statline-staging statline-prod; do
  if ! k -n "$ns" get externalsecrets.external-secrets.io -o name 2>/dev/null | grep -q .; then
    echo "$ns: no ExternalSecrets yet; Argo CD creates them with the new values." >&2
    continue
  fi
  echo "$ns: forcing External Secrets to sync..." >&2
  k -n "$ns" annotate externalsecrets.external-secrets.io --all force-sync="$(date +%s)" --overwrite >/dev/null
  if ! k -n "$ns" wait externalsecrets.external-secrets.io --all --for=condition=Ready --timeout=2m >/dev/null; then
    echo "warning: $ns: an ExternalSecret is not Ready; check kubectl -n $ns describe externalsecret" >&2
  fi
  # Only the Deployments read these at start; each CronJob run starts a new pod with the new Secret.
  k -n "$ns" rollout restart deployment >/dev/null
  echo "$ns: Deployments restarted with the new values." >&2
done
