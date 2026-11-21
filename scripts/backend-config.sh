#!/usr/bin/env bash
# Writes terraform/principal/backend.hcl (gitignored) from the bootstrap outputs. No secrets:
# the S3 backend uses the lab credentials (AWS_PROFILE locally, AWS_* env vars in CI).
set -euo pipefail

bucket="$(terraform -chdir=terraform/bootstrap output -raw state_bucket 2>/dev/null)" || bucket=""
[[ -n "$bucket" ]] || {
  echo "error: no state_bucket output; run make bootstrap (or import the bucket, see README)" >&2
  exit 1
}
region="$(terraform -chdir=terraform/bootstrap output -raw region)"

target=terraform/principal/backend.hcl
printf 'bucket       = "%s"\nkey          = "principal.tfstate"\nregion       = "%s"\nuse_lockfile = true\nencrypt      = true\n' \
  "$bucket" "$region" > "$target"
echo "Wrote $target" >&2
cat "$target"
