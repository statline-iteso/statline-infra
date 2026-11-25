output "region" {
  description = "AWS region of the stack."
  value       = var.region
}

output "cluster_name" {
  description = "aws eks update-kubeconfig --name <this> --alias eks-statline (make kubeconfig)."
  value       = module.eks.cluster_name
}

output "ingress_ip" {
  description = "Elastic IP of the ingress NLB (bootstrap). Hosts: staging.<ip>.nip.io and <ip>.nip.io."
  value       = data.aws_eip.ingress.public_ip
}

output "ssm_prefix" {
  description = "SSM prefix of the app secrets: <prefix>/<env>/<name>, <prefix>/comun/<name>."
  value       = module.seguridad.prefix
}

output "ssm_parameters" {
  description = "Every SSM parameter Terraform manages."
  value       = concat(module.seguridad.parameter_names, flatten(module.identidad[*].parameter_names))
}

output "postgres_address" {
  description = "Private DNS name of RDS PostgreSQL."
  value       = module.datos.address
}

output "postgres_private_cidrs" {
  description = "Private subnet CIDRs: networkPolicies.postgresCidr in the GitOps values."
  value       = module.red.private_cidrs
}

output "log_groups" {
  description = "CloudWatch log groups (EKS control plane, RDS)."
  value       = module.observabilidad.log_groups
}

output "grafana_admin_password" {
  description = "Grafana admin password (user admin). Read with: terraform output -raw grafana_admin_password. Not written to any file."
  value       = module.plataforma.grafana_admin_password
  sensitive   = true
}

output "cognito" {
  description = "Cognito user pool and SPA client per environment, and the admin's username (D-47); null when cognito_enabled is false."
  value = var.cognito_enabled ? {
    user_pool_ids = module.identidad[0].user_pool_ids
    client_ids    = module.identidad[0].client_ids
    admin_email   = module.identidad[0].admin_email
  } : null
}
