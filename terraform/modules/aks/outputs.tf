output "cluster_name" {
  description = "AKS cluster name (az aks get-credentials -n <this>)."
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "AKS cluster id."
  value       = azurerm_kubernetes_cluster.main.id
}

output "node_resource_group" {
  description = "MC_ resource group where AKS puts nodes, the load balancer and public IPs."
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer for workload identity federated credentials."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "identity_principal_id" {
  description = "Principal id of the control-plane identity (granted Network Contributor on the ingress public IP resource group in principal)."
  value       = azurerm_user_assigned_identity.aks.principal_id
}

output "kubelet_object_id" {
  description = "Kubelet identity object id."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "key_vault_csi_identity_client_id" {
  description = "Client id of the Secrets Store CSI add-on identity (SecretProviderClass userAssignedIdentityID)."
  value       = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id
}

output "key_vault_csi_identity_object_id" {
  description = "Object id of the CSI add-on identity (gets Key Vault Secrets User in module seguridad)."
  value       = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
}

output "kube_config" {
  description = "Admin kubeconfig for the kubernetes/helm providers."
  value       = azurerm_kubernetes_cluster.main.kube_config[0]
  sensitive   = true
}
