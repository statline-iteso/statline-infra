variable "ingress_public_ip_address" {
  type        = string
  description = "Static public IP address of the ingress load balancer (principal azurerm_public_ip.ingress)."
}

variable "ingress_public_ip_name" {
  type        = string
  description = "Name of the static public IP resource (service.beta.kubernetes.io/azure-pip-name)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group of the static public IP (service.beta.kubernetes.io/azure-load-balancer-resource-group)."
}

variable "chart_ingress_nginx" {
  type        = string
  description = "ingress-nginx chart version (ingress-nginx/ingress-nginx). Upgrade in its own PR."
  default     = "4.15.1"
}

variable "chart_cert_manager" {
  type        = string
  description = "cert-manager chart version (jetstack/cert-manager)."
  default     = "v1.21.3"
}

variable "chart_argo_cd" {
  type        = string
  description = "Argo CD chart version (argo/argo-cd)."
  default     = "10.11.6"
}

variable "chart_kube_prometheus_stack" {
  type        = string
  description = "kube-prometheus-stack chart version (prometheus-community/kube-prometheus-stack)."
  default     = "92.16.0"
}
