#!/usr/bin/env bash
# Public smoke checks for a deployed environment, from outside the cluster (CI or by hand):
#   scripts/smoke.sh https://staging.example.com
# Checks that <base>/healthz (web, nginx) returns 200, and that <base>/api/ligas returns 401
# without credentials. The Ingress sends /api to the api, and its reads require auth, so 401
# proves the routing reaches the api. Each check retries SMOKE_ATTEMPTS times, SMOKE_INTERVAL
# seconds apart.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <base-url>" >&2
  exit 2
fi
base="${1%/}"
attempts="${SMOKE_ATTEMPTS:-10}"
interval="${SMOKE_INTERVAL:-6}"

# expect <path> <status>: retries until the HTTP status code matches.
expect() {
  local url="$base$1" want="$2" attempt=1 code
  while (( attempt <= attempts )); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url") || code=000
    if [[ "$code" == "$want" ]]; then
      echo "ok    $url -> $code (attempt $attempt)"
      return 0
    fi
    echo "retry $url -> $code (attempt $attempt/$attempts)"
    attempt=$((attempt + 1))
    sleep "$interval"
  done
  echo "FAIL  $url: expected $want after $attempts attempts" >&2
  return 1
}

echo "Smoke checks against $base"
expect /healthz 200
expect /api/ligas 401
echo "public smoke checks passed"
