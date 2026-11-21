variable "name" {
  type        = string
  description = "Cluster name (e.g. statline)."
}

variable "kubernetes_version" {
  type        = string
  description = "EKS minor version. Must be in standard support: aws eks describe-cluster-versions."
}

variable "public_subnet_id" {
  type        = string
  description = "Subnet of the nodes (and of the ingress NLB)."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the control-plane ENIs (second AZ)."
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "Who may reach the public API endpoint (CI runners and laptops: 0.0.0.0/0 by default; auth still applies)."
  default     = ["0.0.0.0/0"]
}

variable "node_instance_type" {
  type        = string
  description = "Node size. The lab allows up to *.large; t3.medium matches the old 2 vCPU / 4 GiB B2s."
  default     = "t3.medium"
}

variable "node_count" {
  type        = number
  description = "Nodes (desired = min). No autoscaler."
  default     = 2
}

variable "node_max_count" {
  type        = number
  description = "Upper bound when scaling by hand (budget: at most 4 nodes, AGENTS §4)."
  default     = 3

  validation {
    condition     = var.node_max_count <= 4
    error_message = "At most 4 nodes (budget rule)."
  }
}

variable "max_pods" {
  type        = number
  description = "kubelet maxPods. 110 is the prefix-delegation value for t3.medium and larger."
  default     = 110
}
