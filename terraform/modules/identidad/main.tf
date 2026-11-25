# identidad: Amazon Cognito user pools, one per environment (D-47). Cognito authenticates (sign-up
# with an emailed code, sign-in, password reset); roles stay in PostgreSQL. The SPA talks to Cognito
# directly (SRP, public client with no secret) and the api checks the ID tokens against the pool's
# public keys, so no pod needs IAM permissions (the lab allows no new roles, D-38).
#
# Pool and client ids change whenever the pools are recreated (every make apply after a destroy),
# so they go to SSM instead of git: External Secrets hands them to the api and to the SPA's config.js.

locals {
  environments = toset(["staging", "prod"])
}

resource "aws_cognito_user_pool" "app" {
  for_each = local.environments
  name     = "${var.name}-${each.key}"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OFF"
  deletion_protection      = "INACTIVE"

  # Short passwords on purpose: the demo admin uses a memorable one (decided with the team, D-47).
  # Cognito's minimum length is 6.
  password_policy {
    minimum_length                   = 6
    require_lowercase                = false
    require_numbers                  = false
    require_symbols                  = false
    require_uppercase                = false
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Cognito's own sender: free, about 50 emails a day per account; enough for a demo.
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "StatLine: tu código de verificación"
    email_message        = "Tu código de verificación de StatLine es {####}"
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }
}

# The SPA's client: public (no secret), SRP sign-in and refresh only.
resource "aws_cognito_user_pool_client" "web" {
  for_each     = local.environments
  name         = "${var.name}-${each.key}-web"
  user_pool_id = aws_cognito_user_pool.app[each.key].id

  generate_secret               = false
  explicit_auth_flows           = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  id_token_validity      = 60
  access_token_validity  = 60
  refresh_token_validity = 7
  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  read_attributes  = ["email", "email_verified", "name"]
  write_attributes = ["email", "name"]
}

# The first ADMIN, created without a password: scripts/set-secrets.sh (make secrets, run by
# make apply) sets it from the Keychain with admin-set-user-password --permanent, so no password
# ever lands in the repo or in the Terraform state.
resource "aws_cognito_user" "admin" {
  for_each     = local.environments
  user_pool_id = aws_cognito_user_pool.app[each.key].id
  username     = var.admin_email

  attributes = {
    email          = var.admin_email
    email_verified = "true"
    name           = "Administrador"
  }
  message_action = "SUPPRESS"

  lifecycle {
    ignore_changes = [password, temporary_password]
  }
}

# Not secrets, but they change per apply: External Secrets reads them like the rest.
resource "aws_ssm_parameter" "pool" {
  for_each = local.environments
  name     = "${var.prefix}/${each.key}/cognito-user-pool-id"
  type     = "String"
  value    = aws_cognito_user_pool.app[each.key].id
}

resource "aws_ssm_parameter" "cliente" {
  for_each = local.environments
  name     = "${var.prefix}/${each.key}/cognito-client-id"
  type     = "String"
  value    = aws_cognito_user_pool_client.web[each.key].id
}
