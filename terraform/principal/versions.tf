terraform {
  # use_lockfile (S3-native state locking) needs 1.10.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # Platform charts (module plataforma), the namespaces and the database Job, configured from
    # module.eks in main.tf. Known caveat: the providers depend on a cluster created in this same
    # stack. See README ("First apply") and `make apply-eks`.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  # Remote state in the bootstrap S3 bucket with S3-native locking (SL-11, D-38). Partial config:
  # `make backend-config` writes backend.hcl (gitignored) from the bootstrap outputs, then
  # `terraform init -backend-config=backend.hcl`.
  backend "s3" {}
}
