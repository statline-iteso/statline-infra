variable "name" {
  type        = string
  description = "Base name for resources."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the cluster."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "subnet_id" {
  type        = string
  description = "Subnet for nodes and pods (module red)."
}

variable "kubernetes_version" {
  type        = string
  description = "AKS minor version (proposal: 1.30). Check `az aks get-versions -l <region>` before applying."
  default     = "1.30"
}

variable "node_vm_size" {
  type        = string
  description = "Node size (proposal: Standard_B2s, 2 vCPU / 4 GiB, burstable)."
  default     = "Standard_B2s"

  validation {
    condition     = can(regex("^Standard_B[0-9]+[a-z]*s?(_v[0-9])?$", var.node_vm_size))
    error_message = "Use a burstable B-series size to stay within the Azure for Students credit."
  }
}

variable "node_min_count" {
  type        = number
  description = "Minimum nodes for the cluster autoscaler."
  default     = 2
}

variable "node_max_count" {
  type        = number
  description = "Maximum nodes for the cluster autoscaler."
  default     = 4

  validation {
    condition     = var.node_max_count <= 4
    error_message = "At most 4 nodes (Azure for Students vCPU quota and budget)."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource."
  default     = {}
}
