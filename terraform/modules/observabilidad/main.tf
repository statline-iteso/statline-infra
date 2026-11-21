# observabilidad: CloudWatch log groups for the EKS control plane and the RDS PostgreSQL log,
# created before the services that write to them so retention is short (cost; D-19, D-38). In-cluster
# metrics and dashboards stay on kube-prometheus-stack (module plataforma).

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.retention_days
}

resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${var.db_identifier}/postgresql"
  retention_in_days = var.retention_days
}
