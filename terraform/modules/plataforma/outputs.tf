output "namespace_plataforma" {
  description = "Namespace of the shared platform charts."
  value       = kubernetes_namespace.ambiente["plataforma"].metadata[0].name
}

output "grafana_admin_password" {
  description = "Grafana admin password (user admin). Sensitive; only in the Terraform state and the Grafana Secret."
  value       = random_password.grafana.result
  sensitive   = true
}
