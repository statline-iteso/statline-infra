#!/usr/bin/env bash
# Runs inside `make bootstrap`, after `terraform init` and before the plan. The bootstrap state is
# local, so it can disagree with the lab account in three ways; this script fixes each, touching
# only the state (it never creates or deletes anything in AWS):
#   1. The state is from another lab account: move it to terraform/bootstrap/archive/<account>/.
#   2. The state holds the old aws_s3_bucket (the lab's SCP breaks its reads, D-38): forget it.
#   3. The bucket or the Elastic IP exists in AWS but not in the state (lost state, or a failed
#      first apply): import it, so the plan adopts it instead of creating a second one.
set -euo pipefail

cd "$(dirname "$0")/../terraform/bootstrap"
TF=${TF:-terraform}
REGION=${AWS_REGION:-us-east-1}
PROJECT=statline

log() { printf '%s\n' "$*" >&2; }

account=$(aws sts get-caller-identity --region "$REGION" --query Account --output text)
bucket="$PROJECT-tfstate-$account"

# 1. State from another account.
if [[ -f terraform.tfstate ]]; then
  recorded=$(jq -r '.outputs.account_id.value // (.outputs.state_bucket.value // "" | split("-") | last)' terraform.tfstate)
  if [[ -n "$recorded" && "$recorded" != "$account" ]]; then
    log "Bootstrap state is for account $recorded, but the credentials are for $account."
    log "Moving it to terraform/bootstrap/archive/$recorded/ (gitignored)."
    mkdir -p "archive/$recorded"
    for f in terraform.tfstate terraform.tfstate.*backup bootstrap.tfplan; do
      [[ -e "$f" ]] && mv "$f" "archive/$recorded/"
    done
  fi
fi

in_state() { [[ -f terraform.tfstate ]] && $TF state list 2>/dev/null | grep -qx "$1"; }

# 2. Old aws_s3_bucket entries: drop them from the state (the bucket itself stays).
if [[ -f terraform.tfstate ]]; then
  for r in $($TF state list 2>/dev/null | grep -E '^aws_s3_bucket(_[a-z_]+)?\.tfstate$' || true); do
    log "Forgetting $r (replaced by awscc_s3_bucket.tfstate; nothing is deleted)."
    $TF state rm -lock=false "$r" >/dev/null
  done
fi

# 3. Adopt what already exists.
if ! in_state awscc_s3_bucket.tfstate && aws s3api head-bucket --bucket "$bucket" --region "$REGION" >/dev/null 2>&1; then
  log "Bucket $bucket exists: importing it."
  $TF import -input=false awscc_s3_bucket.tfstate "$bucket" >/dev/null
fi

eip=$(aws ec2 describe-addresses --region "$REGION" --filters "Name=tag:Name,Values=$PROJECT-ingress" \
  --query 'Addresses[0].AllocationId' --output text)
if ! in_state aws_eip.ingress && [[ -n "$eip" && "$eip" != None ]]; then
  log "Elastic IP $eip ($PROJECT-ingress) exists: importing it."
  $TF import -input=false aws_eip.ingress "$eip" >/dev/null
fi

log "Bootstrap state matches account $account."
