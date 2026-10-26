terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = "~> 0.1"
    }
  }

  # Account, container and key are passed by scripts/run-stack.sh per customer environment
  backend "azurerm" {
    use_azuread_auth = true
  }
}
