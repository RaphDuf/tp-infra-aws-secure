variable "region" {
  description = "Region AWS (imposee par AWS Academy)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixe de nommage des ressources"
  type        = string
  default     = "TP_G6"
}

variable "my_ip" {
  description = "Votre IP publique en /32 (acces SSH au bastion)"
  type        = string
  # a renseigner dans terraform.tfvars, ex : "203.0.113.10/32"
}

variable "admin_ip" {
  description = "Votre IP publique en /32 (acces SSH au bastion et Ansible Master)"
  type        = string
}
