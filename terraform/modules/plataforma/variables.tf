variable "ingress_eip_allocation_id" {
  type        = string
  description = "Elastic IP of the ingress NLB (bootstrap stack; service.beta.kubernetes.io/aws-load-balancer-eip-allocations)."
}

variable "db_address" {
  type        = string
  description = "RDS address (names the database Job)."
}

variable "db_admin_url" {
  type        = string
  description = "Master connection string to the postgres database (module datos)."
  sensitive   = true
}

variable "bases_de_datos" {
  type        = list(string)
  description = "Databases the Job creates when missing."
}

variable "chart_external_secrets" {
  type        = string
  description = "External Secrets Operator chart version (external-secrets/external-secrets)."
  default     = "2.14.0"
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
