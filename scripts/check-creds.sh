#!/usr/bin/env bash
# Fails fast when the Learner Lab credentials are missing or expired. AWS-touching make targets
# depend on `check-creds`. Locally it uses AWS_PROFILE (statline-lab, exported by the Makefile);
# in CI, where the Makefile leaves AWS_PROFILE unset, it uses the AWS_* secrets from make creds.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"

command -v aws >/dev/null || { echo "error: aws CLI not found; run mise install" >&2; exit 1; }

if ! account="$(aws sts get-caller-identity --region "$REGION" --query Account --output text 2>/dev/null)"; then
  echo "error: lab credentials${AWS_PROFILE:+ (profile $AWS_PROFILE)} missing or expired; run make creds" >&2
  exit 1
fi

echo "Lab credentials OK (account $account${AWS_PROFILE:+, profile $AWS_PROFILE})" >&2
