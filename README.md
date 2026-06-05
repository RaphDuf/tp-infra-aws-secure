# Projet final - Architecture AWS automatisée & sécurisée (Terraform + Ansible)

Équipe : Axel Malka, Mathéo Harison, Ambrine Zaouche, Raphaël Duflot

---

## 1. Contexte

Notre équipe joue le rôle d'une équipe DevSecOps en entreprise. Mission : concevoir et déployer une **infrastructure AWS sécurisée et 100% automatisée** : un bastion + un Ansible master, un serveur web privé (nginx), un serveur FTP privé (vsftpd), le tout durci par Ansible.

---

## 2. Ce que contient ce dépôt

```
projet-final/
|-- README.md                   ce fichier
|-- .gitignore                  exclut *.pem, terraform.tfstate, .terraform/
|-- Makefile                    make deploy / make destroy
|-- terraform/
|   |-- provider.tf             aws ~>6, tls, local
|   |-- variables.tf            region, project, admin_ip
|   |-- main.tf                 point d'entrée — appelle les modules
|   |-- outputs.tf              IPs utiles après apply
|   |-- terraform.tfvars        votre IP publique (non commité)
|   `-- modules/
|       |-- network/            VPC, subnets public/privés, IGW, NAT Gateway, routes
|       |-- security/           Security Groups least-privilege + NACL subnet privé
|       `-- compute/            EC2 bastion, Ansible master, web, FTP + clés SSH
`-- ansible/
    |-- ansible.cfg
    |-- site.yml                playbook principal (web + ftp + hardening)
    |-- inventory.tftpl         inventaire généré par Terraform
    `-- roles/
        |-- webserver/          installe et configure nginx
        |-- ftpserver/          installe et configure vsftpd
        `-- hardening/          durcissement SSH, firewall hôte, mises à jour auto
```

---

## 3. Prérequis AWS Academy

- **Start Lab** (voyant vert), puis collez vos identifiants (*AWS Details → AWS CLI → Show*) dans `~/.aws/credentials`.
- Région `us-east-1`, instances `t3.micro`, AMI Amazon Linux 2023, profil `LabInstanceProfile` (pas de création IAM).
- Les identifiants expirent à chaque arrêt de lab : réactualisez-les après chaque *Start Lab*.
- Récupérez votre IP publique avant le déploiement :
  ```bash
  curl -s ifconfig.me
  ```
  Renseignez-la dans `terraform/terraform.tfvars` :
  ```hcl
  admin_ip = "X.X.X.X"   # votre IP sans /32
  project  = "devsecops"
  ```

---

## 4. Déploiement

Le déploiement complet se fait en deux étapes : Terraform crée l'infrastructure, puis Ansible configure et durcit les serveurs.

```bash
# 1. Cloner le dépôt et se placer à la racine
git clone <url-du-repo> && cd projet-final

# 2. Déploiement complet (infrastructure + configuration)
make deploy

# 3. Destruction propre en fin de séance (OBLIGATOIRE — NAT Gateway facturée)
make destroy
```

**Détail des commandes `make` :**

```bash
# Équivalent make deploy :
cd terraform && terraform init && terraform apply -auto-approve
cd ../ansible && ansible-playbook site.yml -i inventory.ini

# Équivalent make destroy :
cd terraform && terraform destroy -auto-approve
```

> ⚠️ Vérifiez après `terraform destroy` : aucune EC2, NAT Gateway, ni VPC résiduel dans la console. Puis cliquez **End Lab**.

---

## 5. Choix d'architecture & justifications

### 5.1 Réseau (`modules/network`)

| Ressource | CIDR | AZ | Rôle |
|---|---|---|---|
| VPC | `10.0.0.0/16` | — | Réseau isolé dédié au projet |
| Subnet public | `10.0.1.0/24` | us-east-1a | Bastion, Ansible master, NAT Gateway |
| Subnet privé A | `10.0.10.0/24` | us-east-1a | Serveur web (nginx) |
| Subnet privé B | `10.0.11.0/24` | us-east-1b | Serveur FTP (vsftpd) |

**VPC dédié**
Isoler l'infra du VPC par défaut AWS empêche tout trafic accidentel avec d'autres ressources Academy. Le `/16` offre 65 536 adresses, suffisant pour étendre le projet (bonus supervision, ALB…) sans reconfiguration.

**Séparation public / privé**
Les serveurs web et FTP n'ont aucune IP publique (`map_public_ip_on_launch = false`). Ils sont uniquement joignables via le bastion. Même en cas de vulnérabilité sur nginx ou vsftpd, le service n'est pas exposé directement à Internet.

**Une seule NAT Gateway (us-east-1a)**
Choix économique justifié par les contraintes Academy : la NAT est facturée à l'heure. En production, on déploierait une NAT par AZ pour la haute disponibilité. Elle permet aux instances privées de télécharger des paquets (`dnf update`) sans être joignables depuis l'extérieur.

**CIDRs non contigus (`10.0.1.x` vs `10.0.10.x`)**
L'espacement entre les plages publique et privée rend les règles de firewall immédiatement lisibles : toute règle ciblant `10.0.10.0/24` désigne sans ambiguïté un subnet privé.

### 5.2 Sécurité (`modules/security`)

**Security Groups — référencement par ID de SG**

| SG | Ports entrants autorisés | Source |
|---|---|---|
| `sg-bastion` | TCP 22 | `<admin_ip>/32` uniquement |
| `sg-ansible` | TCP 22 | `sg-bastion` |
| `sg-web` | TCP 22, TCP 80 | `sg-bastion`, `sg-ansible` |
| `sg-ftp` | TCP 22, TCP 21, TCP 50000–51000 | `sg-bastion`, `sg-ansible` |

Les règles inter-composants référencent l'**ID du Security Group** source plutôt qu'une plage CIDR. Si le CIDR d'un subnet change, les règles restent valides. C'est aussi plus précis : on autorise exactement les instances du SG bastion, pas toute la plage `10.0.1.0/24`.

**Bastion : SSH restreint à `<admin_ip>/32`**
Le `/32` désigne une seule adresse IP exacte. Ouvrir le port 22 sur `0.0.0.0/0` exposerait le bastion aux attaques par brute-force depuis l'ensemble d'Internet. Si l'IP change (DHCP), il suffit de mettre à jour `terraform.tfvars` et de relancer `terraform apply`.

**Plage FTP passive 50000–51000**
vsftpd en mode passif choisit un port de données dans une plage configurable. On fixe cette plage dans `vsftpd.conf` via Ansible et on l'ouvre exactement dans le SG. Ouvrir tous les ports hauts (`1024–65535`) serait excessif et contraire au principe de moindre privilège.

**NACL sur les subnets privés (couche stateless)**

| Sens | Règle | Ports | Source/Dest | Action |
|---|---|---|---|---|
| Entrée | 100 | TCP 22 | `10.0.1.0/24` | ALLOW |
| Entrée | 200 | TCP 1024–65535 | `0.0.0.0/0` | ALLOW |
| Sortie | 100 | TCP 80 | `0.0.0.0/0` | ALLOW |
| Sortie | 110 | TCP 443 | `0.0.0.0/0` | ALLOW |
| Sortie | 200 | TCP 1024–65535 | `10.0.1.0/24` | ALLOW |

Les Security Groups sont *stateful* (la réponse rentre automatiquement si la requête sortante est autorisée). Les NACL sont *stateless* : chaque sens doit être explicitement autorisé. La NACL constitue une seconde ligne de défense indépendante — une erreur de configuration sur un SG ne suffit plus à exposer une instance.

Les **ports éphémères (1024–65535) en entrée** sont nécessaires car la NACL étant stateless, les réponses aux requêtes `dnf update` sortantes reviennent sur un port aléatoire dans cette plage. Sans cette règle, les mises à jour échoueraient silencieusement.

---

## 6. Nettoyage

```bash
make destroy
```

Vérifiez dans la console AWS qu'il ne reste aucune ressource résiduelle (EC2, NAT Gateway, Elastic IP, VPC), puis cliquez **End Lab**.