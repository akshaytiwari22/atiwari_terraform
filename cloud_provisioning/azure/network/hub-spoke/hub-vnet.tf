locals {
  prefix-hub         = "hub"
  hub-location       = "WestUS2"
  hub-resource-group = "hub-vnet-rg"
  shared-key         = "4-v3ry-53cr37-1p53c-5h4r3d-k3y"
}

resource "azurerm_resource_group" "hub-vnet-rg" {
  location = local.hub-location
  name     = local.hub-resource-group
}

resource "azurerm_virtual_network" "hub-vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.hub-vnet-rg.location
  name                = "${local.prefix-hub}-vnet"
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  tags = {
    environment = "hub-spoke"
  }
}

resource "azurerm_subnet" "hub-gateway-subnet" {
  address_prefix       = "10.0.255.224/27"
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
}

resource "azurerm_subnet" "hub-mgmt" {
  address_prefix       = "10.0.0.64/27"
  name                 = "mgmt"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
}

resource "azurerm_subnet" "hub-dmz" {
  address_prefix       = "10.0.0.32/27"
  name                 = "dmz"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
}

resource "azurerm_subnet" "hub-bastion" {
  address_prefix       = "10.0.5.0/27"
  name                 = "bastion"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
}

resource "azurerm_public_ip" "bastion-pip" {
  name                = "bastionpip"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "hub-vnet-bastion" {
  name                = "${local.prefix-hub}-bastion}"
  location            = azurerm_resource_group.hub-vnet-rg.location
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name
}


resource "azurerm_network_interface" "hub-nic" {
  location             = azurerm_resource_group.hub-vnet-rg.location
  name                 = "${local.prefix-hub}-nic"
  resource_group_name  = azurerm_resource_group.hub-vnet-rg.name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = local.prefix-hub
    subnet_id                     = azurerm_subnet.hub-mgmt.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = local.prefix-hub
  }
}

#Creating virtual machine
resource "azurerm_virtual_machine" "hub-vm" {
  location              = azurerm_resource_group.hub-vnet-rg.location
  name                  = "${local.prefix-hub}-vm"
  network_interface_ids = [azurerm_network_interface.hub-nic.id]
  resource_group_name   = azurerm_resource_group.hub-vnet-rg.name
  vm_size               = var.vmsize
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.prefix-hub}-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = local.prefix-hub
  }
}

# Creating Virtual Network Gateway
resource "azurerm_public_ip" "hub-vpn-gateway1-pip" {
  location            = azurerm_resource_group.hub-vnet-rg.location
  name                = "hub-vpn-gateway1-pip"
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name

  allocation_method = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "hub-vnet-gateway" {
  location            = azurerm_resource_group.hub-vnet-rg.location
  name                = "hub-vpn-gateway1"
  resource_group_name = azurerm_resource_group.hub-vnet-rg.name
  sku                 = "VpnGw1"
  type                = "Vpn"
  vpn_type            = "RouteBased"

  active_active = false
  enable_bgp    = false

  ip_configuration {
    subnet_id                     = azurerm_subnet.hub-gateway-subnet.id
    public_ip_address_id          = azurerm_public_ip.hub-vpn-gateway1-pip.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_public_ip.hub-vpn-gateway1-pip]
}

resource "azurerm_virtual_network_gateway_connection" "hub-onprem-conn" {
  location                        = azurerm_resource_group.hub-vnet-rg.location
  name                            = "hub-onprem-conn"
  resource_group_name             = azurerm_resource_group.hub-vnet-rg.name
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.hub-vnet-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem-vpn-gateway.id

  shared_key = local.shared-key
}

resource "azurerm_virtual_network_gateway_connection" "onprem-hub-conn" {
  location                        = azurerm_resource_group.onprem-vnet-rg.location
  name                            = "onprem-hub-conn"
  resource_group_name             = azurerm_resource_group.onprem-vnet-rg.name
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.onprem-vpn-gateway.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.hub-vnet-gateway.id

  shared_key = local.shared-key
}