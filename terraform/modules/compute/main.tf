# ===========================================================
# 1. Génération de la paire de clés SSH
# ===========================================================
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Sauvegarde de la clé privée en local (attention au .gitignore !)
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.root}/${var.project}-key.pem"
  file_permission = "0400"
}

# ===========================================================
# 2. Récupération de la dernière AMI Amazon Linux 2023
# ===========================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ===========================================================
# 3. Instances PUBLIQUES (Bastion & Ansible Master)
# ===========================================================
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.sg_bastion_id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = "LabInstanceProfile"

  tags = { Name = "${var.project}-bastion" }
}

resource "aws_instance" "ansible_master" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.sg_ansible_id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = "LabInstanceProfile"

  tags = { Name = "${var.project}-ansible-master" }
}

# ===========================================================
# 4. Instances PRIVÉES (Web & FTP)
# ===========================================================
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_id_a # On le met dans l'AZ 'a'
  vpc_security_group_ids = [var.sg_web_id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = "LabInstanceProfile"

  tags = { Name = "${var.project}-web" }
}

resource "aws_instance" "ftp" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_id_b # On le met dans l'AZ 'b' (bonne pratique)
  vpc_security_group_ids = [var.sg_ftp_id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = "LabInstanceProfile"

  tags = { Name = "${var.project}-ftp" }
}
