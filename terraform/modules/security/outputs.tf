output "sg_bastion_id" { value = aws_security_group.bastion.id }
output "sg_ansible_id" { value = aws_security_group.ansible.id }
output "sg_web_id" { value = aws_security_group.web.id }
output "sg_ftp_id" { value = aws_security_group.ftp.id }
