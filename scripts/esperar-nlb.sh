#!/usr/bin/env bash
# Waits until the ingress NLB is gone. The EKS cloud controller creates it for the ingress-nginx
# Service, outside Terraform; it is deleted asynchronously after the Service. Destroying the VPC
# while it still exists fails on the subnet and internet gateway, so `make destroy` removes the
# platform charts first, runs this, then destroys the rest.
set -euo pipefail

cluster=${CLUSTER_NAME:-statline}
region=${AWS_REGION:-us-east-1}

nlbs() {
  local arns
  arns=$(aws elbv2 describe-load-balancers --region "$region" --query 'LoadBalancers[].LoadBalancerArn' --output text)
  [[ -n "$arns" && "$arns" != None ]] || return 0
  # shellcheck disable=SC2086 # word splitting of the ARN list is intended
  aws elbv2 describe-tags --region "$region" --resource-arns $arns \
    --query "TagDescriptions[?Tags[?Key=='kubernetes.io/cluster/${cluster}']].ResourceArn" --output text
}

for _ in $(seq 1 40); do
  left=$(nlbs)
  if [[ -z "$left" || "$left" == None ]]; then
    echo "No load balancer of cluster $cluster left." >&2
    exit 0
  fi
  echo "Waiting for the ingress NLB to be deleted..." >&2
  sleep 15
done
echo "error: the NLB of cluster $cluster still exists after 10 minutes; delete it in the console (EC2 → Load Balancers), then rerun make destroy" >&2
exit 1
