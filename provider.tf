terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
# This provider configuration is for Azure Resource Manager (azurerm).
# It specifies that the azurerm provider should be sourced from HashiCorp and uses version 3.0 or higher.
# The `features {}` block is required for the azurerm provider to function correctly.       