output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ansible_master_public_ip" {
  value = aws_instance.ansible_master.public_ip
}

output "ansible_master_private_ip" {
  value = aws_instance.ansible_master.private_ip
}

output "web_private_ip" {
  value = aws_instance.web.private_ip
}

output "ftp_private_ip" {
  value = aws_instance.ftp.private_ip
}