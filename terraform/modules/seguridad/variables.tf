variable "name" {
  type        = string
  description = "Base name for resources (e.g. statline)."
}

variable "suffix" {
  type        = string
  description = "Random suffix: Key Vault names are globally unique."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the Key Vault."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "csi_identity_object_id" {
  type        = string
  description = "Object id of the Secrets Store CSI add-on identity (module aks); gets Key Vault Secrets User."
}

variable "database_urls" {
  type        = map(string)
  description = "DATABASE_URL per environment (keys staging and prod), from module datos."
  sensitive   = true

  validation {
    condition     = alltrue([for env in ["staging", "prod"] : contains(keys(var.database_urls), env)])
    error_message = "database_urls must contain the keys staging and prod."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource."
  default     = {}
}
