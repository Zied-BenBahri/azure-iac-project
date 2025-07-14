resource "azurerm_public_ip" "proxy_ip" {
  name                = "pip-proxy"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}
resource "azurerm_public_ip" "iis01_ip" {
  name                = "pip-iis01"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_public_ip" "iis02_ip" {
  name                = "pip-iis02"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}
