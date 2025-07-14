# WinRM Setup for vm-proxy
resource "azurerm_virtual_machine_extension" "winrm_proxy" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.proxy_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -File enable-winrm.ps1"
  })

  protected_settings = jsonencode({
    script = file("${path.module}/scripts/enable-winrm.ps1")
  })

  depends_on = [azurerm_windows_virtual_machine.proxy_vm]
}

# WinRM Setup for vm-iis-01
resource "azurerm_virtual_machine_extension" "winrm_iis01" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_iis_01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -File enable-winrm.ps1"
  })

  protected_settings = jsonencode({
    script = file("${path.module}/scripts/enable-winrm.ps1")
  })

  depends_on = [azurerm_windows_virtual_machine.vm_iis_01]
}

# WinRM Setup for vm-iis-02
resource "azurerm_virtual_machine_extension" "winrm_iis02" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_iis_02.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -File enable-winrm.ps1"
  })

  protected_settings = jsonencode({
    script = file("${path.module}/scripts/enable-winrm.ps1")
  })

  depends_on = [azurerm_windows_virtual_machine.vm_iis_02]
}
