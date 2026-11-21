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
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

# Deterministic name (project + account id): scripts and CI can derive it without reading this state.
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Old state versions are kept 30 days, enough to roll back a bad apply.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    id     = "expire-noncurrent-state"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# Public address of the ingress NLB (principal attaches it through the
# aws-load-balancer-eip-allocations annotation). Idle, it bills as one public IPv4 (~USD 3.60/month).
resource "aws_eip" "ingress" {
  domain = "vpc"
  tags = {
    Name = "${var.project}-ingress"
  }
}
