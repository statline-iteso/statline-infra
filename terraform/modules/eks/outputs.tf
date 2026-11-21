output "cluster_name" {
  description = "aws eks update-kubeconfig --name <this>"
  value       = aws_eks_cluster.main.name
}

output "endpoint" {
  description = "API server endpoint (kubernetes and helm providers)."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 CA of the API server."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group EKS creates and attaches to the nodes (RDS allows 5432 from it)."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_group_id" {
  description = "Managed node group (dependency for the platform charts)."
  value       = aws_eks_node_group.main.id
}
