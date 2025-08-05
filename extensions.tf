resource "azurerm_virtual_machine_extension" "iis01_setup" {
  name                 = "iis-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_iis_01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "fileUris" = [
      "https://raw.githubusercontent.com/Zied-BenBahri/azure-iac-project/main/scripts/setup-iis-optimized.ps1"
    ],
  "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File setup-iis-optimized.ps1" })

  timeouts {
    create = "60m"
    update = "60m"
    delete = "10m"
  }

  depends_on = [azurerm_windows_virtual_machine.vm_iis_01]
}

resource "azurerm_virtual_machine_extension" "iis02_setup" {
  name                 = "iis-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_iis_02.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    "fileUris" = [
      "https://raw.githubusercontent.com/Zied-BenBahri/azure-iac-project/main/scripts/setup-iis-optimized.ps1"
    ],
  "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File setup-iis-optimized.ps1" })

  timeouts {
    create = "60m"
    update = "60m"
    delete = "10m"
  }

  depends_on = [azurerm_windows_virtual_machine.vm_iis_02]
}

resource "azurerm_virtual_machine_extension" "monitor_script" {
  name                 = "setup-monitoring"
  virtual_machine_id   = azurerm_linux_virtual_machine.monitor_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    fileUris         = ["https://raw.githubusercontent.com/Zied-BenBahri/azure-iac-project/main/scripts/setup-monitoring.sh"]
    commandToExecute = "bash setup-monitoring.sh"
  })

  timeouts {
    create = "15m"
    update = "15m"
    delete = "10m"
  }

  depends_on = [azurerm_linux_virtual_machine.monitor_vm]
}
