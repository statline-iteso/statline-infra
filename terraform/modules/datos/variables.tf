variable "name" {
  type        = string
  description = "Base name for resources (e.g. statline)."
}

variable "identifier" {
  type        = string
  description = "RDS instance identifier (also names its CloudWatch log group, module observabilidad)."
}

variable "vpc_id" {
  type        = string
  description = "VPC of the database security group."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets in two AZs (DB subnet group)."
}

variable "cluster_security_group_id" {
  type        = string
  description = "EKS cluster security group, the only source allowed on 5432."
}

variable "instance_class" {
  type        = string
  description = "RDS instance class. Burstable only (budget)."
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.t[34]g?\\.", var.instance_class))
    error_message = "Burstable classes only (db.t3.*, db.t4g.*)."
  }
}

variable "admin_login" {
  type        = string
  description = "Master user name."
  default     = "statline_admin"
}

variable "bases_de_datos" {
  type        = list(string)
  description = "Application databases, one per environment (statline_<env>)."
  default     = ["statline_staging", "statline_prod"]
}
