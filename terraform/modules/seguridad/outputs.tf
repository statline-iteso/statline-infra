output "prefix" {
  description = "SSM prefix: <prefix>/<env>/<name> and <prefix>/comun/<name>."
  value       = var.prefix
}

output "parameter_names" {
  description = "Every parameter Terraform manages."
  value       = concat([for p in aws_ssm_parameter.ambiente : p.name], [for p in aws_ssm_parameter.comun : p.name])
}
