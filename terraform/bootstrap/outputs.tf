output "account_id" {
  description = "Lab account this state belongs to (scripts/bootstrap-account.sh compares it)."
  value       = data.aws_caller_identity.current.account_id
}

output "state_bucket" {
  description = "S3 bucket that holds remote state (written into principal/backend.hcl)."
  value       = awscc_s3_bucket.tfstate.bucket_name
}

output "region" {
  description = "Region of the bucket and of every stack."
  value       = var.region
}

output "ingress_eip_allocation_id" {
  description = "Allocation id of the ingress Elastic IP (principal reads it by its Name tag)."
  value       = aws_eip.ingress.allocation_id
}

output "ingress_ip" {
  description = "Public address of the ingress: hosts are staging.<ip>.nip.io and <ip>.nip.io."
  value       = aws_eip.ingress.public_ip
}
