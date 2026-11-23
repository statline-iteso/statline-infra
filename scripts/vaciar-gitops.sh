#!/usr/bin/env bash
# Deletes the Argo CD Applications and the ExternalSecrets while their controllers still run, so
# their finalizers are honoured. `make destroy` runs it before removing the platform charts.
# Removing the charts first leaves those finalizers with no controller: the CRD or namespace
# deletion then hangs (2026-11-23: the external-secrets uninstall timed out after 5 minutes).
# Uses a throwaway kubeconfig, never the default context.
set -euo pipefail

cluster=${CLUSTER_NAME:-statline}
region=${AWS_REGION:-us-east-1}

if ! aws eks describe-cluster --name "$cluster" --region "$region" >/dev/null 2>&1; then
  echo "Cluster $cluster not found; nothing to empty." >&2
  exit 0
fi

kc=$(mktemp)
trap 'rm -f "$kc"' EXIT
aws eks update-kubeconfig --name "$cluster" --region "$region" --kubeconfig "$kc" >/dev/null
k() { kubectl --kubeconfig "$kc" "$@"; }

if k get crd applications.argoproj.io >/dev/null 2>&1; then
  # root first: with auto-sync on, it would recreate the child Applications. Its finalizer makes
  # Argo CD delete the children, and theirs prune the app resources (ExternalSecret included).
  echo "Deleting the Argo CD Applications (Argo CD prunes their resources)..." >&2
  k -n plataforma delete applications.argoproj.io root --ignore-not-found --wait=true --timeout=5m
  k -n plataforma delete applications.argoproj.io --all --wait=true --timeout=5m
fi

if k get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then
  echo "Deleting any ExternalSecret left..." >&2
  k delete externalsecrets.external-secrets.io --all-namespaces --all --wait=true --timeout=2m
fi
echo "GitOps resources removed; the platform charts can go." >&2
