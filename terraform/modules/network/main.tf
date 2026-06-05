# ===========================================================
# VPC principal
# Toute notre infra vit dans ce réseau isolé.
# CIDR /16 = 65 536 adresses disponibles, largement suffisant.
# ===========================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Nécessaire pour que les instances aient un hostname résolvable
  enable_dns_support   = true

  tags = { Name = "${var.project}-vpc" }
}

# ===========================================================
# Internet Gateway — la "porte d'entrée" vers Internet
# Sans elle, rien dans le subnet public ne peut communiquer
# avec l'extérieur.
# ===========================================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

# ===========================================================
# Subnet PUBLIC — bastion + Ansible master + NAT Gateway
# On utilise l'AZ us-east-1a (obligatoire pour Academy)
# ===========================================================
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Les instances publiques reçoivent une IP publique auto

  tags = { Name = "${var.project}-subnet-public" }
}

# ===========================================================
# Subnets PRIVÉS — serveur web + serveur FTP
# Deux subnets privés dans deux AZ différentes (bonne pratique)
# mais une seule NAT Gateway suffit (économie sur Academy)
# ===========================================================
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr_a
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false # Jamais d'IP publique sur les privés !

  tags = { Name = "${var.project}-subnet-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr_b
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = { Name = "${var.project}-subnet-private-b" }
}

# ===========================================================
# Elastic IP pour la NAT Gateway
# La NAT Gateway a besoin d'une IP publique fixe pour sortir
# sur Internet au nom des instances privées.
# ===========================================================
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project}-nat-eip" }
}

# ===========================================================
# NAT Gateway — permet aux instances PRIVÉES de sortir sur
# Internet (pour les mises à jour apt/dnf) sans être joignables
# depuis l'extérieur. Elle vit dans le subnet PUBLIC.
# ATTENTION : coûte de l'argent → terraform destroy en fin de séance !
# ===========================================================
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags       = { Name = "${var.project}-nat" }
  depends_on = [aws_internet_gateway.igw]
}

# ===========================================================
# Table de routage PUBLIC
# Tout le trafic non-local (0.0.0.0/0) part vers l'IGW
# ===========================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project}-rt-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ===========================================================
# Table de routage PRIVÉ
# Le trafic sortant des privés passe par la NAT Gateway,
# PAS par l'IGW directement → les serveurs restent injoignables
# depuis Internet.
# ===========================================================
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "${var.project}-rt-private" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
