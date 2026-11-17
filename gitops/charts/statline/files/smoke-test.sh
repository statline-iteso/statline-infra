#!/bin/sh
# Post-deploy smoke checks, run inside the cluster by the smoke-test Job (Argo CD PostSync hook
# and Helm post-install/post-upgrade hook) and by `make smoke`. Each check retries SMOKE_ATTEMPTS
# times, SMOKE_INTERVAL seconds apart. The first check that never returns HTTP 200 fails the run.
#
# Environment: SMOKE_WEB, SMOKE_API, SMOKE_PREDICCIONES are the base URLs of the Services.
# The pod must carry the label statline.io/smoke=true: the NetworkPolicies let it reach
# web, api and predicciones.
set -eu

ATTEMPTS="${SMOKE_ATTEMPTS:-10}"
INTERVAL="${SMOKE_INTERVAL:-6}"

check() {
  url="$1"
  attempt=1
  while [ "$attempt" -le "$ATTEMPTS" ]; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url") || code=000
    if [ "$code" = "200" ]; then
      echo "ok    $url -> 200 (attempt $attempt)"
      return 0
    fi
    echo "retry $url -> $code (attempt $attempt/$ATTEMPTS)"
    attempt=$((attempt + 1))
    sleep "$INTERVAL"
  done
  echo "FAIL  $url did not return 200 after $ATTEMPTS attempts"
  return 1
}

check "$SMOKE_WEB/healthz"
check "$SMOKE_API/healthz"
check "$SMOKE_API/readyz"
check "$SMOKE_PREDICCIONES/healthz"
check "$SMOKE_PREDICCIONES/readyz"
echo "all smoke checks passed"
