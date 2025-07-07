variable "location" {
  default = "East US"
}

variable "resource_group_name" {
  default = "rg-internship"
}

variable "vnet_cidr" {
  default = "10.0.0.0/16"
}
variable "admin_username" {
  default = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for VMs"
  sensitive   = true
}
