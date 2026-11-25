# Everything StatLine runs on, in one stack (proposal §4.1), on the AWS Learner Lab (D-38). One EKS
# cluster hosts the statline-staging and statline-prod namespaces; one RDS instance hosts their
# databases. The state bucket and the ingress Elastic IP live in the bootstrap stack.

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# Kubernetes and Helm talk to the cluster created in module eks. The token comes from
# `aws eks get-token` on every call (it expires after 15 minutes, shorter than a full apply). On a
# cluster that does not exist yet these values are unknown at plan time: apply module eks first
# (`make apply-eks`), see README "First apply".
provider "kubernetes" {
  host                   = module.eks.endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

# Created once by the bootstrap stack (make bootstrap); kept across make destroy.
data "aws_eip" "ingress" {
  filter {
    name   = "tag:Name"
    values = ["${local.name}-ingress"]
  }
}

module "red" {
  source       = "../modules/red"
  name         = local.name
  cluster_name = local.name
  azs          = var.azs
}

# Log groups first, so EKS and RDS write into groups with short retention.
module "observabilidad" {
  source         = "../modules/observabilidad"
  cluster_name   = local.name
  db_identifier  = local.db_identifier
  retention_days = var.log_retention_days
}

module "eks" {
  source              = "../modules/eks"
  name                = local.name
  kubernetes_version  = var.kubernetes_version
  public_subnet_id    = module.red.public_subnet_id
  private_subnet_ids  = module.red.private_subnet_ids
  public_access_cidrs = var.cluster_public_access_cidrs
  node_instance_type  = var.node_instance_type
  node_count          = var.node_count

  depends_on = [module.observabilidad]
}

module "datos" {
  source                    = "../modules/datos"
  name                      = local.name
  identifier                = local.db_identifier
  vpc_id                    = module.red.vpc_id
  private_subnet_ids        = module.red.private_subnet_ids
  cluster_security_group_id = module.eks.cluster_security_group_id

  depends_on = [module.observabilidad]
}

module "seguridad" {
  source        = "../modules/seguridad"
  prefix        = "/${local.name}"
  database_urls = module.datos.database_urls
}

# Cognito user pools for the app's users (D-47). Off by default until the lab is confirmed to allow
# Cognito: make apply TF_VAR_cognito_enabled=true (or cognito_enabled in terraform.tfvars).
module "identidad" {
  count  = var.cognito_enabled ? 1 : 0
  source = "../modules/identidad"
  name   = local.name
  prefix = "/${local.name}"
}

module "plataforma" {
  source = "../modules/plataforma"

  ingress_eip_allocation_id = data.aws_eip.ingress.id
  db_address                = module.datos.address
  db_admin_url              = module.datos.admin_url
  bases_de_datos            = module.datos.database_names

  # Charts need nodes to schedule on, and CoreDNS.
  depends_on = [module.eks]
}
