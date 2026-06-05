output "vpc_id" {
  description = "ID du VPC"
  value       = module.network.vpc_id
}

# >>> A COMPLETER : exposez les sorties utiles a la correction et a Ansible
# (IP publique du bastion, IPs privees des serveurs web et du serveur de supervision...)
