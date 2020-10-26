locals {
  nsg-location       = "WestUS2"
  nsg-resource-group = "nsg-rg"
  prefix-nsg         = "nsg"
}

resource "azurerm_resource_group" "nsg-rg" {
  name     = local.nsg-resource-group
  location = local.nsg-location
}

resource "azurerm_network_watcher" "nsg-watcher" {
  name                = "${local.prefix-nsg}-watcher"
  location            = azurerm_resource_group.nsg-rg.location
  resource_group_name = azurerm_resource_group.nsg-rg.name
}

resource "azurerm_storage_account" "nsg-storage-account" {
  name                = "${local.prefix-nsg}-storage-account}"
  resource_group_name = azurerm_resource_group.nsg-rg.name
  location            = azurerm_resource_group.nsg-rg.location

  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
}

resource "azurerm_log_analytics_workspace" "nsg-law" {
  name                = "${local.prefix-nsg}-law"
  location            = azurerm_resource_group.nsg-rg.location
  resource_group_name = azurerm_resource_group.nsg-rg.name
  sku                 = "PerGB2018"
}

resource "azurerm_network_watcher_flow_log" "nsg-wfl" {
  network_watcher_name = azurerm_network_watcher.nsg-watcher.name
  resource_group_name  = azurerm_resource_group.nsg-rg.name

  network_security_group_id = azurerm_network_security_group.onprem-nsg.id
  storage_account_id        = azurerm_storage_account.nsg-storage-account.id
  enabled                   = true

}