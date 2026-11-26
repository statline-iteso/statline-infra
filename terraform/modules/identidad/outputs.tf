output "user_pool_ids" {
  description = "Cognito user pool id per environment."
  value       = { for env, p in aws_cognito_user_pool.app : env => p.id }
}

output "client_ids" {
  description = "SPA app client id per environment."
  value       = { for env, c in aws_cognito_user_pool_client.web : env => c.id }
}

output "admin_email" {
  description = "Username (email) of the first ADMIN in every pool."
  value       = var.admin_email
}

output "parameter_names" {
  description = "SSM parameters with the pool and client ids."
  value       = concat([for p in aws_ssm_parameter.pool : p.name], [for p in aws_ssm_parameter.cliente : p.name])
}
