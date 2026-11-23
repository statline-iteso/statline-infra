output "log_groups" {
  description = "CloudWatch log groups (EKS control plane, RDS PostgreSQL)."
  value       = [aws_cloudwatch_log_group.eks.name, aws_cloudwatch_log_group.rds.name]
}
