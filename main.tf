# Define Provider
provider "azurerm" {

    features {
      
    }
}

# Create Resource Groups
resource "azurerm_resource_group" "apache_terraform_rg" {
    name    = var.resource_group_name
    location = var.location

    lifecycle {
      prevent_destroy = false
    }
}

#Create azure storage account
resource "azurerm_storage_account" "apache_terraform_sa" {
  name                     = "${var.prefix}sa"
  resource_group_name      = azurerm_resource_group.apache_terraform_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

#Create virtual network for the VM
resource "azurerm_virtual_network" "apache_terraform_vnet" {
  name                = var.virtual_network_name
  location            = var.location
  address_space       = var.address_space
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
}

#Create subnet to the virtual network
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}_subnet"
  virtual_network_name = azurerm_virtual_network.apache_terraform_vnet.name
  resource_group_name  = azurerm_resource_group.apache_terraform_rg.name
  address_prefixes     = var.subnet_prefix
}

#Create public ip
resource "azurerm_public_ip" "apache_terraform_pip" {
  name                = "${var.prefix}-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name
  allocation_method   = "Dynamic"
  domain_name_label   = var.hostname
}

#Create Network security group
resource "azurerm_network_security_group" "apache_terraform_sg" {
  name                = "${var.prefix}-sg"
  location            = var.location
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name

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

}

#Create Network interface
resource "azurerm_network_interface" "apache_terraform_nic" {
  name                = "${var.prefix}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.apache_terraform_rg.name

  ip_configuration {
    name                          = "${var.prefix}-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.apache_terraform_pip.id
  }
}
