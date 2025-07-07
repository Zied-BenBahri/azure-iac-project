# Resource Group
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "resource_group_location" {
  value = azurerm_resource_group.main.location
}

# Virtual Network
output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "vnet_address_space" {
  value = azurerm_virtual_network.main.address_space
}

# Subnets
output "frontend_subnet" {
  value = {
    name   = azurerm_subnet.frontend.name
    prefix = azurerm_subnet.frontend.address_prefixes
  }
}

output "backend_subnet" {
  value = {
    name   = azurerm_subnet.backend.name
    prefix = azurerm_subnet.backend.address_prefixes
  }
}

output "monitoring_subnet" {
  value = {
    name   = azurerm_subnet.monitoring.name
    prefix = azurerm_subnet.monitoring.address_prefixes
  }
}

output "gateway_subnet" {
  value = {
    name   = azurerm_subnet.gateway.name
    prefix = azurerm_subnet.gateway.address_prefixes
  }
}

# Public IP
output "proxy_public_ip" {
  value = azurerm_public_ip.proxy_ip.ip_address
}
# Virtual Machines
output "proxy_vm" {
  value = {
    name     = azurerm_windows_virtual_machine.proxy_vm.name
    location = azurerm_windows_virtual_machine.proxy_vm.location
    size     = azurerm_windows_virtual_machine.proxy_vm.size
  }
}
output "monitor_vm" {
  value = {
    name     = azurerm_linux_virtual_machine.monitor_vm.name
    location = azurerm_linux_virtual_machine.monitor_vm.location
    size     = azurerm_linux_virtual_machine.monitor_vm.size
  }
}
output "vm-iis-01" {
  value = {
    name     = azurerm_windows_virtual_machine.vm_iis_01.name
    location = azurerm_windows_virtual_machine.vm_iis_01.location
    size     = azurerm_windows_virtual_machine.vm_iis_01.size
  }
}
output "vm-iis-02" {
  value = {
    name     = azurerm_windows_virtual_machine.vm_iis_02.name
    location = azurerm_windows_virtual_machine.vm_iis_02.location
    size     = azurerm_windows_virtual_machine.vm_iis_02.size
  }
}
