resource "azurerm_virtual_machine_extension" "iis01_setup" {
  name                 = "iis-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_iis_01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "fileUris" = [
      "https://raw.githubusercontent.com/Zied-BenBahri/azure-iac-project/main/scripts/setup-iis.ps1"
    ],
    "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File setup-iis.ps1"
  })
}
resource "azurerm_virtual_machine_extension" "iis02_setup" {
  name                 = "iis-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_iis_02.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "fileUris" = [
      "https://raw.githubusercontent.com/Zied-BenBahri/azure-iac-project/main/scripts/setup-iis.ps1"
    ],
    "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File setup-iis.ps1"
  })
}
resource "azurerm_virtual_machine_extension" "proxy_setup" {
  name                 = "proxy-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.proxy_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "fileUris" = [
      "https://raw.githubusercontent.com/Zied-BenBahri/azure-iac-project/main/scripts/setup-proxy.ps1"
    ],
    "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File setup-proxy.ps1"
  })
}
