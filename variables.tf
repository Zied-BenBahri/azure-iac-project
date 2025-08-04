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
variable "sql_server_connection_string" {
  description = "Connection string for on-premises SQL Server"
  type        = string
  default     = "Server=tcp:172.16.0.130,1433;Database=BlazorCrudApp;User Id=blazoruser;Password=BlazorApp2024!;TrustServerCertificate=true;MultipleActiveResultSets=true;Connection Timeout=30;"
  sensitive   = true
}

variable "blazor_app_release_url" {
  description = "GitHub release URL for Blazor application zip"
  type        = string
  default     = "https://raw.githubusercontent.com/Zied-BenBahri/azure-iac-project/main/releases/blazorapp.zip"
}
