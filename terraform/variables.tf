variable "api_url" {
  description = "CloudStack API endpoint"
  type        = string
  default     = "https://dku.kloud.zone/client/api"
}

variable "api_key" {
  description = "Solid Cloud API key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Solid Cloud secret key"
  type        = string
  sensitive   = true
}

variable "name_prefix" {
  description = "Student ID used as resource name suffix"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{8}$", var.name_prefix))
    error_message = "name_prefix must be an 8-digit student ID."
  }
}

variable "zone_name" {
  description = "CloudStack zone"
  type        = string
  default     = "DKU"
}

variable "template_regex" {
  description = "Anchored regex for the featured template"
  type        = string
  default     = "^Ubuntu_24.04$"
}

variable "vpc_offering" {
  description = "VPC offering name"
  type        = string
  default     = "Default VPC offering"
}

variable "tier_network_offering" {
  description = "Network offering for VPC tiers"
  type        = string
  default     = "DefaultIsolatedNetworkOfferingForVpcNetworks"
}

variable "service_offering" {
  description = "Compute offering for every VM"
  type        = string
  default     = "Small"

  validation {
    condition     = contains(["Small", "Medium"], var.service_offering)
    error_message = "Only Small or Medium is allowed within the student quota."
  }
}

variable "root_disk_size" {
  description = "Root disk size in GiB"
  type        = number
  default     = 20
}

variable "vpc_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "web_cidr" {
  type    = string
  default = "192.168.10.0/24"
}

variable "data_cidr" {
  type    = string
  default = "192.168.20.0/24"
}

variable "mgmt_cidr" {
  type    = string
  default = "192.168.30.0/24"
}

variable "web_count" {
  description = "Number of web nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.web_count >= 2 && var.web_count <= 3
    error_message = "web_count must be 2 or 3 to keep redundancy within quota."
  }
}

variable "admin_cidrs" {
  description = "Source CIDRs allowed to reach the bastion SSH port"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "bastion_public_port" {
  type    = number
  default = 2222
}

variable "use_vr_lb" {
  description = "Use the VPC virtual router load balancer for HTTPS; false falls back to port forwarding to web01"
  type        = bool
  default     = true
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Private key used only by Terraform provisioners to push secrets and run the bootstrap over the bastion"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "repo_url" {
  description = "Public Git repository that holds the bootstrap scripts"
  type        = string
}

variable "repo_ref" {
  description = "Git commit or tag checked out by the bootstrap"
  type        = string
  default     = "main"
}

variable "app_image" {
  description = "Container image of the application, pinned by tag or digest"
  type        = string
}

variable "app_domain" {
  description = "Hostname placed in the TLS certificate"
  type        = string
  default     = "evlocker.test"
}

variable "vm_mtu" {
  description = "Guest NIC MTU. Path MTU inside the Solid Cloud VPC was measured at 1450, so 1400 leaves headroom"
  type        = number
  default     = 1400

  validation {
    condition     = var.vm_mtu >= 1280 && var.vm_mtu <= 1450
    error_message = "vm_mtu must be between 1280 and 1450."
  }
}
