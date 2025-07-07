resource "azurerm_public_ip" "proxy_ip" {
  name                = "pip-proxy"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}
