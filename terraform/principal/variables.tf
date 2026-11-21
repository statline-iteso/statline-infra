variable "region" {
  type        = string
  description = "AWS region. The Learner Lab only allows us-east-1 (the Makefile pins it)."
  default     = "us-east-1"

  validation {
    condition     = var.region == "us-east-1"
    error_message = "The AWS Learner Lab only allows us-east-1."
  }
}

variable "azs" {
  type        = list(string)
  description = "Two AZs; the first holds the nodes and the ingress NLB."
  default     = ["us-east-1a", "us-east-1b"]
}

variable "kubernetes_version" {
  type        = string
  description = "EKS minor version, in standard support (aws eks describe-cluster-versions). 1.35 on 2026-11-21."
  default     = "1.35"
}

variable "node_instance_type" {
  type        = string
  description = "Node size. Burstable, at most *.large (lab policy)."
  default     = "t3.medium"

  validation {
    condition     = can(regex("^t3a?\\.(small|medium|large)$", var.node_instance_type))
    error_message = "Burstable t3/t3a small, medium or large only (budget and lab policy)."
  }
}

variable "node_count" {
  type        = number
  description = "Number of nodes (fixed: no autoscaler)."
  default     = 2
}

variable "cluster_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed on the public EKS API endpoint. Narrow to your IP for a demo; CI runners need it open."
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch retention for the EKS control-plane and RDS logs."
  default     = 3
}

variable "owner" {
  type        = string
  description = "Value of the Owner tag."
  default     = "statline-iteso"
}
