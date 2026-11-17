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
    # Platform charts (module plataforma) and the namespaces, configured from module.aks in main.tf.
    # Known caveat: the providers depend on a cluster created in this same stack. See README
    # ("First apply") and `make apply-aks`.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }

  # Remote state in the bootstrap storage account, with blob-lease locking (SL-11).
  # Partial config: `make backend-config` writes backend.hcl (gitignored) from the bootstrap
  # outputs, then `terraform init -backend-config=backend.hcl`.
  backend "azurerm" {
    key              = "principal.tfstate"
    use_azuread_auth = true
  }
}
