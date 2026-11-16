terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # TODO(SL-12): kubernetes ~> 2.33 and helm ~> 2.16 for the plataforma module.
  }

  # Remote state in the bootstrap storage account, with blob-lease locking (SL-11).
  # Partial config: `make backend-config` writes backend.hcl (gitignored) from the bootstrap
  # outputs, then `terraform init -backend-config=backend.hcl`.
  backend "azurerm" {
    key              = "principal.tfstate"
    use_azuread_auth = true
  }
}
