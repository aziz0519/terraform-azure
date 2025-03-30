terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.91.0"
    }
  }
}

provider "azurerm" {
  features {

  }
  subscription_id = "962d6403-6d94-4df8-9a25-1a03d9103dfa"

}

resource "azurerm_resource_group" "ntc-rg" {
  name     = "ntc-resources"
  location = "East US"
  tags = {
    environment = "dev"
  }

}

resource "azurerm_virtual_network" "ktc-vm" {
  name                = "ktc-network"
  resource_group_name = azurerm_resource_group.ntc-rg.name
  location            = azurerm_resource_group.ntc-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "ktc-subnet" {
  name                 = "ktc-subnet"
  resource_group_name  = azurerm_resource_group.ntc-rg.name
  virtual_network_name = azurerm_virtual_network.ktc-vm.name
  address_prefixes     = ["10.123.1.0/24"]

}

resource "azurerm_network_security_group" "ktc-sg" {
  name                = "ktc-sg"
  location            = azurerm_resource_group.ntc-rg.location
  resource_group_name = azurerm_resource_group.ntc-rg.name

  tags = {
    environment = "dev"
  }

}

resource "azurerm_network_security_rule" "ktc-dev-rule" {
  name                        = "ktc-dev-rule"
  priority                    = "100"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "192.168.0.11/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ntc-rg.name
  network_security_group_name = azurerm_network_security_group.ktc-sg.name

}

resource "azurerm_subnet_network_security_group_association" "name" {
  subnet_id                 = azurerm_subnet.ktc-subnet.id
  network_security_group_id = azurerm_network_security_group.ktc-sg.id

}

resource "azurerm_public_ip" "ktc-ip" {
  name                = "ktc-ip"
  resource_group_name = azurerm_resource_group.ntc-rg.name
  location            = azurerm_resource_group.ntc-rg.location
  allocation_method   = "Static"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "ktc-nic" {
  name                = "ktc-nic"
  location            = azurerm_resource_group.ntc-rg.location
  resource_group_name = azurerm_resource_group.ntc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ktc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ktc-ip.id
  }

  tags = {
    environment = "dev"
  }

}

resource "azurerm_linux_virtual_machine" "ktc-vm" {
  name                  = "mtc-vm"
  resource_group_name   = azurerm_resource_group.ntc-rg.name
  location              = azurerm_resource_group.ntc-rg.location
  size                  = "Standard_A1_v2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.ktc-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/xtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"

  }


  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }


  provisioner "local-exec" {
    command = templatefile("windows-ssh-script.tpl",{
        hostname = self.public_ip_address,
        user = "adminuser",
        identityfile = "~/.ssh/xtcazurekey"
    })
    
  }

  tags = {
    environment = "dev"
  }

}