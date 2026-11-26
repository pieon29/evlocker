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

variable "shared_network_id" {
  description = "ID of the Solid Cloud Shared Network (console: Network > Guest Networks > Shared Network)"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f-]{36}$", var.shared_network_id))
    error_message = "shared_network_id must be the UUID shown in the console."
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

variable "web_count" {
  description = "Number of web nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.web_count >= 2 && var.web_count <= 3
    error_message = "web_count must be 2 or 3 to keep redundancy within quota."
  }
}

variable "vm_mtu" {
  description = "Guest NIC MTU and TCP MSS clamp base"
  type        = number
  default     = 1400

  validation {
    condition     = var.vm_mtu >= 1280 && var.vm_mtu <= 1500
    error_message = "vm_mtu must be between 1280 and 1500."
  }
}

variable "ssh_public_key_path" {
  description = "Public key installed for the ubuntu user"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Private key used only by Terraform provisioners to push secrets and run the bootstrap"
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

variable "api_rate_limit" {
  description = "Per-client request rate limit on /api/ in requests per second"
  type        = number
  default     = 50

  validation {
    condition     = var.api_rate_limit >= 1 && var.api_rate_limit <= 5000
    error_message = "api_rate_limit must be between 1 and 5000."
  }
}

variable "app_domain" {
  description = "Hostname placed in the TLS certificate"
  type        = string
  default     = "evlocker.test"
}
