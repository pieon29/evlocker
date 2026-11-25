variable "name" {
  type = string
}

variable "offering_id" {
  type = string
}

variable "template_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "network_id" {
  type = string
}

variable "ip_address" {
  type = string
}

variable "root_disk_size" {
  type    = number
  default = 20
}

variable "user_data" {
  type      = string
  sensitive = true
}
