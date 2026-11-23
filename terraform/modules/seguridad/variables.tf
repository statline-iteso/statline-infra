variable "prefix" {
  type        = string
  description = "SSM path prefix (e.g. /statline)."
  default     = "/statline"
}

variable "database_urls" {
  type        = map(string)
  description = "DATABASE_URL per environment (staging, prod), from module datos."
  sensitive   = true
}
