# =============================================================================
# Point d'entree Terraform.
# Le socle ne contient qu'un module reseau MINIMAL (VPC + 1 subnet public).
# A VOUS de batir le reste de l'architecture demandee dans le cahier des charges.
# =============================================================================

module "network" {
  source  = "./modules/network"
  project = var.project
}

# -----------------------------------------------------------------------------
# >>> A CONSTRUIRE <<<
# - sous-reseaux PRIVES (+ NAT Gateway pour la sortie Internet des prives)
# - module "security" : Security Groups least-privilege + au moins une NACL
# - module "compute"  : bastion + Ansible master (PUBLICS) ; serveurs web et
#                       serveur de supervision (PRIVES) ; cle SSH (tls + aws_key_pair)
# - inventaire Ansible genere via templatefile (groupes : web, supervision...)
# - (BONUS) ALB, GuardDuty/Security Hub, Auto Scaling...
#
# Exemple d'appel d'un futur module :
#   module "compute" {
#     source             = "./modules/compute"
#     project            = var.project
#     private_subnet_ids = module.network.private_subnet_ids
#     ...
#   }
# -----------------------------------------------------------------------------
