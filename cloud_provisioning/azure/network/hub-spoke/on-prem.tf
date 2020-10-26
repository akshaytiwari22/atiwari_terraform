locals {
  onprem-location = "WestUS2"
  onprem-resource-group = "onprem-vnet-rg"
  prefix-onprem = "onprem"
}

resource "azurerm_resource_group" "onprem-vnet-rg" {
  location = local.onprem-location
  name = local.onprem-resource-group
}

resource "azurerm_virtual_network" "onprem-vnet" {
  address_space = ["192.168.0.0/16"]
  location = azurerm_resource_group.onprem-vnet-rg.location
  name = "onprem-vnet"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name

  tags {
    environment = local.prefix-onprem
  }
}

resource "azurerm_subnet" "onprem-gateway-subnet" {
  address_prefix = "192.168.255.224/27"
  name = "GatewaySubnet"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
}

resource "azurerm_subnet" "onprem-mgmt" {
  address_prefix = "192.168.1.128/25"
  name = "mgmt"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
}

resource "azurerm_public_ip" "onprem-pip" {
  location = azurerm_resource_group.onprem-vnet-rg.location
  name = "${local.prefix-onprem}-pip"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  allocation_method = "Dynamic"

  tags {
    environment = local.prefix-onprem
  }
}

resource "azurerm_network_interface" "onprem-inc" {
  location = azurerm_resource_group.onprem-vnet-rg.location
  name = "${local.prefix-onprem}-nic"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  ip_configuration {
    name = local.prefix-onprem
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.onprem-mgmt.id
    public_ip_address_id = azurerm_public_ip.onprem-pip.id
  }
}

#Create the Network security Group and rule
resource "azurerm_network_security_group" "onprem-nsg" {
  location = azurerm_resource_group.onprem-vnet-rg.location
  name = "${local.prefix-onprem}-nsg"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name

  security_rule {
    access = "Allow"
    direction = "Inbound"
    name = "SSH"
    priority = 1001
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "onprem"
  }
}

resource "azurerm_subnet_network_security_group_association" "mgmt-nsg-association" {
  network_security_group_id = azurerm_network_security_group.onprem-nsg.id
  subnet_id = azurerm_subnet.onprem-mgmt.id
}

resource "azurerm_virtual_machine" "onprem-vm" {
  location = azurerm_resource_group.onprem-vnet-rg.location
  name = "${local.prefix-onprem}-vm"
  network_interface_ids = [azurerm_network_interface.onprem-inc.id]
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  vm_size = var.vmsize
  storage_os_disk {
    create_option = "FromImage"
    name = "myosdisk1"
    caching = "ReadWrite"
    managed_disk_type = "Standard_LRS"
  }
  storage_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
    version = "latest"
  }
  os_profile {
    admin_username = var.username
    computer_name = "${local.prefix-onprem}-vm"
    admin_password = var.password
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags {
    environment = local.prefix-onprem
  }
}

resource "azurerm_public_ip" "onprem-vpn-gateway1-pip" {
  location = azurerm_resource_group.onprem-vnet-rg.location
  name = "${local.prefix-onprem}-vpn-gateway1-pip"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "onprem-vpn-gateway" {
  location = azurerm_resource_group.onprem-vnet-rg.location
  name = "onprem-vpn-gateway1"
  resource_group_name = azurerm_resource_group.onprem-vnet-rg.name
  sku = "VpnGw1"
  type = "Vpn"
  vpn_type = "RouteBased"
  active_active = false
  enable_bgp = false

  ip_configuration {
    subnet_id = azurerm_subnet.onprem-gateway-subnet.id
    name = "vnetGatewayConfig"
    public_ip_address_id = azurerm_public_ip.onprem-vpn-gateway1-pip.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [azurerm_public_ip.onprem-vpn-gateway1-pip]
}