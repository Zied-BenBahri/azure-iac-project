# Monitoring resources (keep unchanged)
resource "azurerm_network_interface" "monitor_nic" {
  name                = "nic-monitor"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.monitoring.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.monitor_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "monitor_vm" {
  name                            = "vm-monitor"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = "Standard_DS1_v2"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.monitor_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# NICs for IIS VMs (keep unchanged)
resource "azurerm_network_interface" "iis01_nic" {
  name                = "nic-iis01"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "iis02_nic" {
  name                = "nic-iis02"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Data source to reference the existing custom image
data "azurerm_image" "vm_iis_image" {
  name                = "vm-iis-blazor-image"
  resource_group_name = azurerm_resource_group.main.name
}

# VM: vm-iis-01 (Recreated from custom image)
resource "azurerm_windows_virtual_machine" "vm_iis_01" {
  name                  = "vm-iis-01"
  location              = var.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = "Standard_B2ms"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.iis01_nic.id]

  # Use custom image with pre-installed Blazor app
  # source_image_id = data.azurerm_image.vm_iis_image.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  tags = {
    Environment = "Production"
    Role        = "WebServer"
    Application = "BlazorApp"
  }

  # depends_on = [data.azurerm_image.vm_iis_image]
}

# VM: vm-iis-02 (Created from custom image)
resource "azurerm_windows_virtual_machine" "vm_iis_02" {
  name                = "vm-iis-02"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.iis02_nic.id,
  ]

  # Use custom image with pre-installed Blazor app
  # source_image_id = data.azurerm_image.vm_iis_image.id

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  tags = {
    Environment = "Production"
    Role        = "WebServer"
    Application = "BlazorApp"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  # depends_on = [data.azurerm_image.vm_iis_image]
}

