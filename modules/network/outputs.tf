output "vnet_id" {
  description = "ID of the AKS virtual network."
  value       = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "ID of the AKS subnet."
  value       = azurerm_subnet.aks.id
}

output "subnet_name" {
  description = "Name of the AKS subnet."
  value       = azurerm_subnet.aks.name
}

output "network_security_group_id" {
  description = "Network security group ID associated with the AKS subnet."
  value       = azurerm_network_security_group.aks.id
}
