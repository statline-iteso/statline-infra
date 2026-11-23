variable "cluster_name" {
  type        = string
  description = "EKS cluster name (log group /aws/eks/<name>/cluster)."
}

variable "db_identifier" {
  type        = string
  description = "RDS instance identifier (log group /aws/rds/instance/<id>/postgresql)."
}

variable "retention_days" {
  type        = number
  description = "CloudWatch retention in days."
  default     = 3

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.retention_days)
    error_message = "One of CloudWatch's allowed values up to 30: 1, 3, 5, 7, 14, 30."
  }
}
