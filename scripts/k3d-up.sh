#!/usr/bin/env bash
# Local cluster for the Helm chart: k3d with Traefik disabled (we use ingress-nginx like AKS)
# and the same three namespaces as the real cluster.
set -euo pipefail

if k3d cluster list statline >/dev/null 2>&1; then
  echo "k3d cluster 'statline' already exists"
else
  echo "Creating k3d cluster 'statline' (1 server, 2 agents, ingress on localhost:8080)"
  k3d cluster create --config k3d/cluster.yaml
fi

echo "Installing ingress-nginx"
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx --version 4.11.3 \
  --namespace ingress-nginx --create-namespace --wait

for ns in plataforma statline-staging statline-prod; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Terraform labels the statline namespaces in AKS; the redis NetworkPolicy selects on this key (D-31).
kubectl label namespace statline-staging statline.io/ambiente=staging --overwrite
kubectl label namespace statline-prod statline.io/ambiente=prod --overwrite
kubectl get nodes
