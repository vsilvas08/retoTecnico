terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "tfstatestorage"
    container_name       = "tfstate"
    key                  = "${terraform.workspace}.terraform.tfstate"
  }
}