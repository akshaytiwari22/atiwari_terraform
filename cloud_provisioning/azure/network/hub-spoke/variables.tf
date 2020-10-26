variable "location" {
  description = "Location of the network"
  default     = "westus2"
}

variable "username" {
  description = "Username for the VMs"
  default     = "tfuser"
}

variable "password" {
  description = "Password for the variables"
  default     = "password"
}

variable "vmsize" {
  description = "Size of the VMs"
  default     = "Standard_DS1_v2"
}