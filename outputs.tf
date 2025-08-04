# Load Balancer
output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = azurerm_public_ip.lb_public_ip.ip_address
}

# Virtual Machines
output "vm_iis_01" {
  description = "Details of IIS VM 01"
  value = {
    name       = azurerm_windows_virtual_machine.vm_iis_01.name
    location   = azurerm_windows_virtual_machine.vm_iis_01.location
    size       = azurerm_windows_virtual_machine.vm_iis_01.size
    private_ip = azurerm_network_interface.iis01_nic.private_ip_address
  }
}

output "vm_iis_02" {
  description = "Details of IIS VM 02"
  value = {
    name       = azurerm_windows_virtual_machine.vm_iis_02.name
    location   = azurerm_windows_virtual_machine.vm_iis_02.location
    size       = azurerm_windows_virtual_machine.vm_iis_02.size
    private_ip = azurerm_network_interface.iis02_nic.private_ip_address
  }
}

output "monitor_vm" {
  description = "Details of monitoring VM"
  value = {
    name       = azurerm_linux_virtual_machine.monitor_vm.name
    location   = azurerm_linux_virtual_machine.monitor_vm.location
    size       = azurerm_linux_virtual_machine.monitor_vm.size
    public_ip  = azurerm_public_ip.monitor_ip.ip_address
    private_ip = azurerm_network_interface.monitor_nic.private_ip_address
  }
}

# Application Access URLs
output "blazor_app_urls" {
  description = "Blazor application access URLs"
  value = {
    load_balancer = "http://${azurerm_public_ip.lb_public_ip.ip_address}/BlazorApp"
    vm_iis_01     = "http://${azurerm_network_interface.iis01_nic.private_ip_address}/BlazorApp"
    vm_iis_02     = "http://${azurerm_network_interface.iis02_nic.private_ip_address}/BlazorApp"
  }
}

# Monitoring URLs
output "monitoring_urls" {
  description = "Monitoring service URLs"
  value = {
    grafana    = "http://${azurerm_public_ip.monitor_ip.ip_address}:3000"
    prometheus = "http://${azurerm_public_ip.monitor_ip.ip_address}:9090"
    wmi_vm1    = "http://${azurerm_network_interface.iis01_nic.private_ip_address}:9182/metrics"
    wmi_vm2    = "http://${azurerm_network_interface.iis02_nic.private_ip_address}:9182/metrics"
  }
}
