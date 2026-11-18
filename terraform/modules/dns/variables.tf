variable "dominio" {
  type        = string
  description = "Public domain of the zone (e.g. statline.example)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the DNS zone."
}

variable "ingress_public_ip" {
  type        = string
  description = "Static public IP of the ingress (principal azurerm_public_ip.ingress)."
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource."
  default     = {}
}
