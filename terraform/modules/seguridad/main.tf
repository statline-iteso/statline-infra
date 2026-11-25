# seguridad: application secrets as SSM Parameter Store SecureStrings (default aws/ssm key, no
# cost). External Secrets syncs them into the Secret statline-secrets of each namespace, reading
# with the nodes' LabRole credentials (D-38). Names are a contract with the chart
# (secrets.external.parameters, docs/ARCHITECTURE.md §3). The API keys are placeholders set out of
# band (`aws ssm put-parameter --overwrite`, RUNBOOK §2.2) and never overwritten by Terraform.

locals {
  environments = toset(["staging", "prod"])
}

resource "random_password" "jwt_secret" {
  for_each = local.environments
  length   = 64
  special  = false
}

resource "random_password" "jwt_refresh_secret" {
  for_each = local.environments
  length   = 64
  special  = false
}

# First ADMIN of each environment (backend D-37).
resource "random_password" "seed_admin" {
  for_each = local.environments
  length   = 32
  special  = false
}

locals {
  por_ambiente = merge([
    for env in local.environments : {
      "${env}/database-url"        = var.database_urls[env]
      "${env}/jwt-secret"          = random_password.jwt_secret[env].result
      "${env}/jwt-refresh-secret"  = random_password.jwt_refresh_secret[env].result
      "${env}/seed-admin-password" = random_password.seed_admin[env].result
    }
  ]...)
}

resource "aws_ssm_parameter" "ambiente" {
  for_each = nonsensitive(toset(keys(local.por_ambiente)))
  name     = "${var.prefix}/${each.key}"
  type     = "SecureString"
  value    = local.por_ambiente[each.key]
}

# Shared by both environments. "set-me" is harmless: the API keys only matter to ingesta, and
# the services treat a Sentry DSN that is not an https URL as no DSN (Sentry off, D-43).
resource "aws_ssm_parameter" "comun" {
  for_each = toset([
    "api-sports-key", "balldontlie-api-key",
    "sentry-dsn-api", "sentry-dsn-predicciones", "sentry-dsn-ingesta", "sentry-dsn-web",
  ])
  name  = "${var.prefix}/comun/${each.key}"
  type  = "SecureString"
  value = "set-me"

  lifecycle {
    ignore_changes = [value]
  }
}
