#!/usr/bin/env bash
# Stores the AWS Learner Lab session credentials in their own profile (default: statline-lab) and
# checks them. Paste the block from "AWS Details → AWS CLI" and press Ctrl-D, or run with
# FROM=clipboard to read it from the macOS clipboard. The [default] header in the pasted block is
# ignored: the keys only ever go to $AWS_PROFILE, never to the default profile.
# The lab keys expire with the session, so run this again at the start of every session.
set -euo pipefail

profile=${AWS_PROFILE:-statline-lab}
region=${LAB_REGION:-us-east-1}

if [[ "${FROM:-}" == clipboard ]]; then
  bloque=$(pbpaste)
else
  [[ -t 0 ]] && echo "Paste the AWS CLI block from the lab (AWS Details), then press Ctrl-D:" >&2
  bloque=$(cat)
fi

valor() {
  # Last "key=value" line for key; spaces around "=" are allowed, as in the lab and in ~/.aws/credentials.
  printf '%s\n' "$bloque" | tr -d '\r' | sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.+)[[:space:]]*$/\1/p" | tail -1
}

key_id=$(valor aws_access_key_id)
secret=$(valor aws_secret_access_key)
token=$(valor aws_session_token)
if [[ -z "$key_id" || -z "$secret" || -z "$token" ]]; then
  echo "Expected aws_access_key_id, aws_secret_access_key and aws_session_token in the pasted block." >&2
  exit 1
fi

aws configure set aws_access_key_id "$key_id" --profile "$profile"
aws configure set aws_secret_access_key "$secret" --profile "$profile"
aws configure set aws_session_token "$token" --profile "$profile"
aws configure set region "$region" --profile "$profile"
unset key_id secret token bloque

echo "Saved profile $profile (region $region). Checking it:" >&2
AWS_PROFILE=$profile aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
