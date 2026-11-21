#!/usr/bin/env bash
# Reads the Learner Lab "AWS CLI" block (AWS Details → AWS CLI → Show), writes it as the
# [statline-lab] profile in ~/.aws/credentials (every other profile, [default] included, is kept),
# checks it against AWS, then pushes it as GitHub Actions secrets to statline-infra, whose CI runs
# `terraform plan`. The backend and frontend never use AWS. Never prints the secrets.
# The lab keys expire with the session: run it again at the start of every session.
#
#   make creds                  # paste the block; it stops reading once all 3 keys are in
#   make creds FROM=clipboard   # read the block from the macOS clipboard (pbpaste)
#
# Env:
#   AWS_PROFILE                  profile to write (default statline-lab; never "default")
#   LAB_REPOS                    space-separated OWNER/REPO list for the secrets (default: statline-infra)
#   SKIP_GH=1                    only write ~/.aws/credentials, don't touch GitHub
#   AWS_SHARED_CREDENTIALS_FILE  honored like the AWS CLI does
set -euo pipefail

PROFILE="${AWS_PROFILE:-statline-lab}"
CREDS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
REGION="${AWS_REGION:-us-east-1}"
LAB_REPOS="${LAB_REPOS:-statline-iteso/statline-infra}"

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }

# The [default] profile belongs to another project on this machine: never overwrite it.
[[ "$PROFILE" != default ]] || die "refusing to write the [default] profile; use AWS_PROFILE=statline-lab"

read_block() {
  if [[ "${FROM:-}" == clipboard ]]; then
    exec < <(pbpaste)
  elif [[ -t 0 ]]; then
    log "Paste the Learner Lab \"AWS CLI\" block (AWS Details → AWS CLI → Show):"
  fi

  key_id="" secret="" token=""
  local line name value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    [[ "$line" == *=* ]] || continue
    name="${line%%=*}"
    value="${line#*=}"
    name="${name//[[:space:]]/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    case "$name" in
      aws_access_key_id)     key_id="$value" ;;
      aws_secret_access_key) secret="$value" ;;
      aws_session_token)     token="$value" ;;
    esac
    [[ -n "$key_id" && -n "$secret" && -n "$token" ]] && break
  done

  local hint="copy the block from AWS Details → AWS CLI → Show"
  [[ "${FROM:-}" == clipboard ]] && hint="the clipboard does not hold the lab block; $hint, then run make creds FROM=clipboard without copying anything else"
  [[ -n "$key_id" ]] || die "aws_access_key_id not found ($hint)"
  [[ -n "$secret" ]] || die "aws_secret_access_key not found ($hint)"
  [[ -n "$token" ]]  || die "aws_session_token not found ($hint)"
}

write_profile() {
  log "Writing the [$PROFILE] profile to $CREDS_FILE"
  mkdir -p "$(dirname "$CREDS_FILE")"
  chmod 700 "$(dirname "$CREDS_FILE")"

  local tmp
  tmp="$(mktemp "${CREDS_FILE}.XXXXXX")"
  chmod 600 "$tmp"
  trap 'rm -f "$tmp"' EXIT

  # Keep every profile except the old [$PROFILE].
  if [[ -f "$CREDS_FILE" ]]; then
    awk -v p="$PROFILE" '
      /^[[:space:]]*\[/ { s = $0; gsub(/[[:space:]]/, "", s); skip = (s == "[" p "]") }
      !skip
    ' "$CREDS_FILE" >"$tmp"
    [[ -s "$tmp" && "$(tail -c1 "$tmp")" != "" ]] && printf '\n' >>"$tmp"
  fi

  # printf is a builtin, so the secrets never show up in `ps`.
  printf '[%s]\naws_access_key_id=%s\naws_secret_access_key=%s\naws_session_token=%s\n' \
    "$PROFILE" "$key_id" "$secret" "$token" >>"$tmp"

  mv "$tmp" "$CREDS_FILE"
  trap - EXIT
  chmod 600 "$CREDS_FILE"
}

check_identity() {
  log "Checking the credentials with sts get-caller-identity"
  local account
  account="$(aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" \
    --query Account --output text)" || die "credentials rejected by AWS; copy the block again from a running lab"
  log "OK: AWS account $account (profile $PROFILE)"
}

push_github_secrets() {
  if [[ "${SKIP_GH:-}" == "1" ]]; then
    log "SKIP_GH=1: not updating GitHub secrets"
    return
  fi
  command -v gh >/dev/null || die "gh not found; install it or rerun with SKIP_GH=1"
  gh auth status >/dev/null 2>&1 || die "gh is not logged in; run 'gh auth login' or rerun with SKIP_GH=1"

  local repo failed=()
  for repo in $LAB_REPOS; do
    log "Updating AWS_* secrets in $repo"
    # No --body: gh reads the value from stdin, so it never appears in `ps`.
    if printf '%s' "$key_id" | gh secret set AWS_ACCESS_KEY_ID --repo "$repo" >/dev/null &&
       printf '%s' "$secret" | gh secret set AWS_SECRET_ACCESS_KEY --repo "$repo" >/dev/null &&
       printf '%s' "$token" | gh secret set AWS_SESSION_TOKEN --repo "$repo" >/dev/null; then
      :
    else
      failed+=("$repo")
    fi
  done

  if (( ${#failed[@]} )); then
    die "could not update secrets in: ${failed[*]}"
  fi
  log "OK: secrets updated in $(wc -w <<<"$LAB_REPOS" | tr -d ' ') repo(s)"
}

read_block
write_profile
check_identity
push_github_secrets
