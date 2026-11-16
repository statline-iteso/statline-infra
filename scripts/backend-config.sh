#!/usr/bin/env bash
# Writes terraform/principal/backend.hcl from the bootstrap outputs (no secrets: Entra ID auth).
set -euo pipefail

out() { terraform -chdir=terraform/bootstrap output -raw "$1"; }

target=terraform/principal/backend.hcl
echo "Writing $target from the bootstrap state"
cat > "$target" <<HCL
resource_group_name  = "$(out resource_group_name)"
storage_account_name = "$(out storage_account_name)"
container_name       = "$(out container_name)"
HCL
cat "$target"
