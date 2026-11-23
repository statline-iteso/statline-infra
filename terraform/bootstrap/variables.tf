variable "region" {
  type        = string
  description = "AWS region. The Learner Lab only allows us-east-1 (the Makefile pins it)."
  default     = "us-east-1"

  validation {
    condition     = var.region == "us-east-1"
    error_message = "The AWS Learner Lab only allows us-east-1."
  }
}

variable "project" {
  type        = string
  description = "Short project name used in resource names."
  default     = "statline"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project))
    error_message = "3-20 lowercase alphanumerics or dashes (it goes into the bucket name)."
  }
}
