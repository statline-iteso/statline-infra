variable "name" {
  type        = string
  description = "Base name for resources (e.g. statline)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the workspace."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "retention_days" {
  type        = number
  description = "Log retention in days (proposal: 30). Azure minimum for PerGB2018 is 30."
  default     = 30

  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "daily_quota_gb" {
  type        = number
  description = "Daily ingestion cap in GB. Stops ingestion when reached, so a noisy resource cannot burn the student credit."
  default     = 0.5

  validation {
    condition     = var.daily_quota_gb > 0
    error_message = "daily_quota_gb must be greater than 0 (-1 means unlimited and is not allowed here)."
  }
}

variable "recursos_diagnostico" {
  type = map(object({
    resource_id    = string
    log_categories = optional(list(string)) # null = allLogs group; list = only these categories
    metrics        = optional(bool, true)   # AllMetrics (the resource must support it)
  }))
  description = "Resources to send to Log Analytics, keyed by a short name (diagnostic setting diag-<key>). Pass resource ids from other modules."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource."
  default     = {}
}
