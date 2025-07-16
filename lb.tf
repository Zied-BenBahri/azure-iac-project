resource "azurerm_lb" "web_lb" {
  name                = "web-load-balancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend-config"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }
}
resource "azurerm_lb_backend_address_pool" "web_backend_pool" {
  name            = "web-backend-pool"
  loadbalancer_id = azurerm_lb.web_lb.id
}
resource "azurerm_lb_probe" "web_probe" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.web_lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "web_lb_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-config"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend_pool.id]
  probe_id                       = azurerm_lb_probe.web_probe.id
}
