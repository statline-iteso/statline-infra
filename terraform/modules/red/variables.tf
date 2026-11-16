variable "name" {
  type        = string
  description = "Base name for resources (e.g. statline)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the network resources."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "address_space" {
  type        = string
  description = "VNet CIDR (proposal §4.1: 10.0.0.0/16)."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.address_space, 0)) && endswith(var.address_space, "/16")
    error_message = "Must be a /16 CIDR; subnets are carved from it."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource."
  default     = {}
}
