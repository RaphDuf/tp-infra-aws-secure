variable "project" {
  type = string
}

# Subnets (provenant du module network)
variable "public_subnet_id" {
  type = string
}

variable "private_subnet_id_a" {
  type = string
}

variable "private_subnet_id_b" {
  type = string
}

# Security Groups (provenant du futur module security)
variable "sg_bastion_id" {
  type = string
}

variable "sg_ansible_id" {
  type = string
}

variable "sg_web_id" {
  type = string
}

variable "sg_ftp_id" {
  type = string
}