variable "name" {
  type        = string
  description = "Name prefix (statline): pools are <name>-staging and <name>-prod."
}

variable "prefix" {
  type        = string
  description = "SSM path prefix (/statline): the pool and client ids go to <prefix>/<env>/cognito-*."
}

variable "admin_email" {
  type        = string
  description = "Email of the first ADMIN; the api's seed gives the matching Usuario row the ADMIN role."
  default     = "admin@statline.local"
}
