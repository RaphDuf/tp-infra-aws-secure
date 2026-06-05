output "bastion_public_ip" {
  value       = module.compute.bastion_public_ip
  description = "IP publique du bastion — point d'entrée SSH"
}

output "ansible_master_public_ip" {
  value       = module.compute.ansible_master_public_ip
  description = "IP publique de l'Ansible master"
}

output "web_private_ip" {
  value       = module.compute.web_private_ip
  description = "IP privée du serveur web"
}

output "ftp_private_ip" {
  value       = module.compute.ftp_private_ip
  description = "IP privée du serveur FTP"
}

output "ssh_key_path" {
  value       = "${path.root}/${var.project}-key.pem"
  description = "Chemin local vers la clé privée SSH"
}

output "ssh_bastion_command" {
  description = "Commande pour se connecter au Bastion"
  value       = "ssh -i ./${var.project}-key.pem ec2-user@${module.compute.bastion_public_ip}"
}

output "ssh_ansible_master_command" {
  description = "Commande pour se connecter à l'Ansible Master (via rebond)"
  value       = "ssh -i ./${var.project}-key.pem -o ProxyCommand=\"ssh -W %h:%p -i ./${var.project}-key.pem ec2-user@${module.compute.bastion_public_ip}\" ec2-user@${module.compute.ansible_master_private_ip}"
}