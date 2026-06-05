# =============================================================
# SECURITY GROUP — BASTION
# Seul composant exposé à Internet.
# On n'ouvre le port 22 QUE depuis votre IP (var.admin_ip).
# Justification : principe du moindre privilège — si on mettait
# 0.0.0.0/0 ici, n'importe qui sur Internet pourrait tenter
# de brute-forcer le bastion.
# =============================================================
resource "aws_security_group" "bastion" {
  name        = "${var.project}-sg-bastion"
  description = "Bastion : SSH entrant depuis IP admin uniquement"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH depuis l'IP admin uniquement"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.admin_ip}/32"] # /32 = une seule IP exacte
  }

  egress {
    description = "Tout le trafic sortant autorisé"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-bastion" }
}

# =============================================================
# SECURITY GROUP — ANSIBLE MASTER
# Même subnet public que le bastion.
# Reçoit le SSH uniquement depuis le bastion (référencement SG).
# Sort librement pour télécharger les rôles Ansible/paquets.
# =============================================================
resource "aws_security_group" "ansible" {
  name        = "${var.project}-sg-ansible"
  description = "Ansible master : SSH depuis bastion uniquement"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH depuis le bastion uniquement"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id] # Référencement SG !
  }

  egress {
    description = "Sortie libre (pour apt/dnf, Galaxy...)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-ansible" }
}

# =============================================================
# SECURITY GROUP — SERVEUR WEB (nginx)
# Dans le subnet privé — aucune IP publique.
# On autorise :
#   - SSH 22 depuis bastion ET ansible master (pour le provisioning)
#   - HTTP 80 depuis le bastion (test via tunnel SSH)
# Justification du port 80 uniquement depuis bastion :
# en prod on mettrait un ALB public devant, pas ici (bonus).
# =============================================================
resource "aws_security_group" "web" {
  name        = "${var.project}-sg-web"
  description = "Serveur web : SSH+HTTP depuis bastion/ansible"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH depuis le bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "SSH depuis Ansible master (provisioning)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ansible.id]
  }

  ingress {
    description     = "HTTP depuis le bastion (tunnel SSH pour test)"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Sortie pour mises à jour via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-web" }
}

# =============================================================
# SECURITY GROUP — SERVEUR FTP (vsftpd)
# Dans le subnet privé — aucune IP publique.
# FTP actif/passif nécessite :
#   - Port 21 (commandes FTP)
#   - Plage passive : 50000-51000 (transfert de données)
# On n'ouvre ces ports QUE depuis le bastion.
# Justification plage passive : vsftpd en mode passif choisit
# un port aléatoire dans cette plage → on doit l'autoriser.
# La plage sera configurée dans vsftpd.conf via Ansible.
# =============================================================
resource "aws_security_group" "ftp" {
  name        = "${var.project}-sg-ftp"
  description = "Serveur FTP : SSH+FTP depuis bastion/ansible"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH depuis le bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "SSH depuis Ansible master (provisioning)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ansible.id]
  }

  ingress {
    description     = "FTP commandes depuis bastion"
    from_port       = 21
    to_port         = 21
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description     = "FTP passif (plage données) depuis bastion"
    from_port       = 50000
    to_port         = 51000
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Sortie pour mises à jour via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-sg-ftp" }
}

# =============================================================
# NACL — SUBNET PRIVÉ
# Couche de sécurité supplémentaire (stateless, contrairement
# aux SG qui sont stateful).
# Justification : le sujet l'exige explicitement sur le privé.
# On bloque tout par défaut et on n'autorise que le nécessaire.
#
# STATELESS = les règles retour doivent être explicites !
# C'est pourquoi on autorise les ports éphémères en sortie.
# =============================================================
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # --- RÈGLES ENTRANTES ---

  # SSH entrant depuis le subnet public uniquement
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_cidr
    from_port  = 22
    to_port    = 22
  }

  # Ports éphémères entrants — réponses aux requêtes sortantes
  # (ex: réponse du serveur apt après une requête de mise à jour)
  # Sans cette règle, les réponses HTTP/HTTPS seraient bloquées !
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # --- RÈGLES SORTANTES ---

  # HTTP sortant (pour télécharger les paquets via NAT)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # HTTPS sortant (repos sécurisés)
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Ports éphémères sortants — réponses SSH vers le subnet public
  egress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_cidr
    from_port  = 1024
    to_port    = 65535
  }

  tags = { Name = "${var.project}-nacl-private" }
}
