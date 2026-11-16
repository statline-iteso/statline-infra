variable "subscription_id" {
  type        = string
  description = "Azure for Students subscription id."
}

variable "location" {
  type        = string
  description = "Azure region (must be allowed by the Azure for Students policy)."
  default     = "eastus2"
}

variable "kubernetes_version" {
  type        = string
  description = "AKS version (proposal: 1.30)."
  default     = "1.30"
}

variable "node_vm_size" {
  type        = string
  description = "AKS node size."
  default     = "Standard_B2s"
}

variable "owner" {
  type        = string
  description = "Value of the Owner tag."
  default     = "statline-iteso"
}
