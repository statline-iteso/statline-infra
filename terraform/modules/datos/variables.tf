variable "name" {
  type        = string
  description = "Base name for resources."
}

variable "suffix" {
  type        = string
  description = "Random suffix: server names are globally unique."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the server."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "subnet_id" {
  type        = string
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers (module red)."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS zone *.postgres.database.azure.com (module red)."
}

variable "sku_name" {
  type        = string
  description = "Server SKU (proposal: B_Standard_B1ms)."
  default     = "B_Standard_B1ms"

  validation {
    condition     = startswith(var.sku_name, "B_")
    error_message = "Burstable SKUs only (Azure for Students budget)."
  }
}

variable "admin_login" {
  type        = string
  description = "Administrator login."
  default     = "statlineadmin"
}

variable "database_name" {
  type        = string
  description = "Application database."
  default     = "statline"
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource."
  default     = {}
}
