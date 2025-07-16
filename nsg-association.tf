/*resource "azurerm_subnet_network_security_group_association" "frontend_assoc" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend_nsg.id
}*/

resource "azurerm_subnet_network_security_group_association" "backend_assoc" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "monitoring_assoc" {
  subnet_id                 = azurerm_subnet.monitoring.id
  network_security_group_id = azurerm_network_security_group.monitoring_nsg.id
}
resource "azurerm_network_interface_backend_address_pool_association" "iis01_lb_association" {
  network_interface_id    = azurerm_network_interface.iis01_nic.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id
  ip_configuration_name   = "ipconfig1" # Matches the name in the NIC's ip_configuration block
}

resource "azurerm_network_interface_backend_address_pool_association" "iis02_lb_association" {
  network_interface_id    = azurerm_network_interface.iis02_nic.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id
  ip_configuration_name   = "ipconfig1" # Matches the name in the NIC's ip_configuration block
}
