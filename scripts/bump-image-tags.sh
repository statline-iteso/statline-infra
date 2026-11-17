#!/usr/bin/env bash
# Sets <image>.image.tag in one environment's values file (used by cd.yml on repository_dispatch
# and workflow_dispatch). Validates everything before touching the file.
#
# Usage: bump-image-tags.sh <staging|prod> <values-file> <pairs-file>
#   pairs-file: one "<image> <tag>" per line.
#     image: web | api | predicciones | ingesta
#     tag:   7 lowercase hex chars (short SHA) or vX.Y.Z (SemVer)
# Prints the commit subject on stdout. Requires yq (mikefarah, v4) on PATH.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <staging|prod> <values-file> <pairs-file>" >&2
  exit 2
fi
env_name=$1
values=$2
pairs=$3

case "$env_name" in
  staging | prod) ;;
  *) echo "invalid environment '$env_name' (staging|prod)" >&2; exit 1 ;;
esac
[[ -f "$values" ]] || { echo "missing values file: $values" >&2; exit 1; }

images=()
tags=()
while read -r image tag extra || [[ -n "${image:-}" ]]; do
  [[ -z "${image:-}" ]] && continue
  if [[ -z "${tag:-}" || -n "${extra:-}" ]]; then
    echo "invalid pair line (expected '<image> <tag>'): $image ${tag:-} ${extra:-}" >&2
    exit 1
  fi
  case "$image" in
    web | api | predicciones | ingesta) ;;
    *) echo "invalid image '$image' (web|api|predicciones|ingesta)" >&2; exit 1 ;;
  esac
  if [[ ! "$tag" =~ ^([0-9a-f]{7}|v[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    echo "invalid tag '$tag' for $image (7 hex chars or vX.Y.Z)" >&2
    exit 1
  fi
  # Image names and tags are validated above, so they are safe to put in the yq expression.
  yq -i ".${image}.image.tag = \"${tag}\"" "$values"
  images+=("$image")
  tags+=("$tag")
done < "$pairs"

if [[ ${#images[@]} -eq 0 ]]; then
  echo "no image tags given" >&2
  exit 1
fi

unique_tags=$(printf '%s\n' "${tags[@]}" | sort -u | wc -l | tr -d ' ')
if [[ "$unique_tags" -eq 1 ]]; then
  printf 'ci(gitops): bump %s to %s in %s\n' "$(IFS=', '; echo "${images[*]}")" "${tags[0]}" "$env_name"
else
  pairs_text=""
  for i in "${!images[@]}"; do
    pairs_text+="${images[$i]}=${tags[$i]}"
    [[ $i -lt $((${#images[@]} - 1)) ]] && pairs_text+=", "
  done
  printf 'ci(gitops): bump %s in %s\n' "$pairs_text" "$env_name"
fi
