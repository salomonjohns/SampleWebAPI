# Define Provider
provider "azurerm" {

    features {
      
    }
}

# Create Resource Groups
resource "azurerm_resource_group" "iis_terraform_rg" {
    name    = var.resource_group_name
    location = var.location

    lifecycle {
      prevent_destroy = false
    }
}

#Create azure storage account
resource "azurerm_storage_account" "iis_terraform_sa" {
  name                     = "${var.prefix}sa"
  resource_group_name      = azurerm_resource_group.iis_terraform_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

#Create virtual network for the VM
resource "azurerm_virtual_network" "iis_terraform_vnet" {
  name                = var.virtual_network_name
  location            = var.location
  address_space       = var.address_space
  resource_group_name = azurerm_resource_group.iis_terraform_rg.name
}

#Create subnet to the virtual network
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}_subnet"
  virtual_network_name = azurerm_virtual_network.iis_terraform_vnet.name
  resource_group_name  = azurerm_resource_group.iis_terraform_rg.name
  address_prefixes     = var.subnet_prefix
}

#Create public ip
resource "azurerm_public_ip" "iis_terraform_pip" {
  name                = "${var.prefix}-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.iis_terraform_rg.name
  allocation_method   = "Dynamic"
  domain_name_label   = var.hostname
}

#Create Network security group
resource "azurerm_network_security_group" "iis_terraform_sg" {
  name                = "${var.prefix}-sg"
  location            = var.location
  resource_group_name = azurerm_resource_group.iis_terraform_rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

# In the event we use https
  security_rule {
    name                       = "HTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Port defined by application
  security_rule {
    name                       = "CUSTOM5251"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5251"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Port defined by application
  # This is not secure, it is open to the world
  security_rule {
    name                       = "WINRM5986"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

#Create Network interface
resource "azurerm_network_interface" "iis_terraform_nic" {
  name                = "${var.prefix}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.iis_terraform_rg.name

  ip_configuration {
    name                          = "${var.prefix}-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.iis_terraform_pip.id
  }
}

#Create VM

resource "azurerm_virtual_machine" "iis_terraform_site" {
  name                = "${var.hostname}-q2"
  location            = var.location
  resource_group_name = azurerm_resource_group.iis_terraform_rg.name
  vm_size             = var.vm_size

  network_interface_ids         = ["${azurerm_network_interface.iis_terraform_nic.id}"]
  delete_os_disk_on_termination = "true"

  storage_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  storage_os_disk {
    name              = "${var.hostname}_osdisk"
    managed_disk_type = "Standard_LRS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = var.hostname
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent = true
    # Disbale updates since I dont want it to possibly reboot during the interview
    enable_automatic_upgrades = false
    winrm {
      protocol = "HTTP"
    }
  }
}
# Install IIS
  resource "azurerm_virtual_machine_extension" "vm_extension_install_iis" {
  name                       = "vm_extension_install_iis"
  virtual_machine_id         = azurerm_virtual_machine.iis_terraform_site.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted mkdir 'C:/temp';Invoke-WebRequest -URI https://q2salomon.blob.core.windows.net/q2salomon/release.zip -OutFile 'C:/temp/release.zip';Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools;Expand-Archive C:/temp/release.zip -DestinationPath C:/inetpub/wwwroot;New-IISSiteBinding -Name 'Default Web Site' -BindingInformation '*:5212:' -Protocol http;ConvertTo-WebApplication -PSPath 'IIS:/Sites/Default Web Site/bin'"
    }
SETTINGS
}
