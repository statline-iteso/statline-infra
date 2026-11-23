# Bootstrap: the S3 bucket that holds every other stack's state, and the Elastic IP of the ingress.
# Its own state is local (terraform/bootstrap/terraform.tfstate, gitignored) because it creates
# the backend the rest depends on. Run once per lab account: `make bootstrap`.
# Both resources outlive `make destroy` of principal: the state must, and the Elastic IP keeps the
# public address (and so the nip.io hosts in the GitOps values) the same across sessions (D-38).

terraform {
  # use_lockfile (S3-native state locking) needs 1.10.
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # The state bucket only: the lab's SCP denies s3:GetBucketObjectLockConfiguration, which every
    # read of aws_s3_bucket calls. awscc (Cloud Control) does not (D-38).
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

locals {
  tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Stack     = "bootstrap"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# awscc has no default_tags: each resource gets these.
provider "awscc" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# Deterministic name (project + account id): scripts and CI derive it without reading this state.
# Versioning, SSE-S3, public access blocked, bucket-owner ownership, old versions kept 30 days.
resource "awscc_s3_bucket" "tfstate" {
  bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"

  versioning_configuration = {
    status = "Enabled"
  }

  bucket_encryption = {
    server_side_encryption_configuration = [{
      server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }]
  }

  public_access_block_configuration = {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }

  ownership_controls = {
    rules = [{
      object_ownership = "BucketOwnerEnforced"
    }]
  }

  lifecycle_configuration = {
    rules = [{
      id     = "expire-noncurrent-state"
      status = "Enabled"
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    }]
  }

  tags = [for k, v in local.tags : { key = k, value = v }]

  lifecycle {
    prevent_destroy = true
  }
}

# Public address of the ingress NLB (principal attaches it through the
# aws-load-balancer-eip-allocations annotation). Idle, it bills as one public IPv4 (~USD 3.60/month).
resource "aws_eip" "ingress" {
  domain = "vpc"
  tags = {
    Name = "${var.project}-ingress"
  }
}
