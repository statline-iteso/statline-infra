variable "name" {
  type        = string
  description = "Base name for resources (e.g. statline)."
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name, for the kubernetes.io/cluster/<name> subnet tag."
}

variable "cidr" {
  type        = string
  description = "VPC CIDR."
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Two AZs: the first holds the public subnet (nodes, NLB). us-east-1e does not support EKS."
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.azs) == 2 && !contains(var.azs, "us-east-1e")
    error_message = "Exactly two AZs, not us-east-1e (EKS does not support it)."
  }
}
