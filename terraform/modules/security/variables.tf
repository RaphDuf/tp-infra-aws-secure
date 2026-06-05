variable "project"            { type = string }
variable "vpc_id"             { type = string }
variable "admin_ip"           { type = string  default = "0.0.0.0/0" }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_cidr" { type = string  default = "10.0.1.0/24" }s