# =============================================================================
# Point d'entrée Terraform principal
# =============================================================================

# -----------------------------------------------------------------------------
# 1. MODULE RÉSEAU (VPC, Subnets, IGW, NAT Gateway)
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  project = var.project
}

# -----------------------------------------------------------------------------
# 2. MODULE SÉCURITÉ (Security Groups & NACL)
# -----------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  project  = var.project
  vpc_id   = module.network.vpc_id
  admin_ip = var.admin_ip

  private_subnet_ids = [module.network.private_subnet_id_a, module.network.private_subnet_id_b]

  public_subnet_cidr = "10.0.1.0/24"
}

# -----------------------------------------------------------------------------
# 3. MODULE COMPUTE (Instances EC2 & Clés SSH)
# -----------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  project = var.project

  # Adressage réseau 
  public_subnet_id    = module.network.public_subnet_id
  private_subnet_id_a = module.network.private_subnet_id_a
  private_subnet_id_b = module.network.private_subnet_id_b

  # Pare-feux 
  sg_bastion_id = module.security.sg_bastion_id
  sg_ansible_id = module.security.sg_ansible_id
  sg_web_id     = module.security.sg_web_id
  sg_ftp_id     = module.security.sg_ftp_id
}

# -----------------------------------------------------------------------------
# 4. GÉNÉRATION DE L'INVENTAIRE ANSIBLE
# templatefile() remplace les variables du .tftpl par les vraies IPs
# -----------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.root}/../ansible/inventory.tftpl", {
    bastion_ip   = module.compute.bastion_public_ip
    web_ip       = module.compute.web_private_ip
    ftp_ip       = module.compute.ftp_private_ip
    ssh_key_path = "${path.root}/${var.project}-key.pem"
  })
  filename = "${path.root}/../ansible/inventory.ini"
}
