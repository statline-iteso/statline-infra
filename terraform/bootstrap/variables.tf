variable "subscription_id" {
  type        = string
  description = "Azure for Students subscription id (az account show --query id -o tsv)."
}

variable "location" {
  type        = string
  description = "Azure region. Azure for Students limits the allowed regions; check the policy."
  default     = "eastus2"
}

variable "project" {
  type        = string
  description = "Short project name used in resource names."
  default     = "statline"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.project))
    error_message = "3-10 lowercase alphanumerics (it goes into the storage account name)."
  }
}
