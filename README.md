# Projet final - Architecture AWS automatisée & sécurisée (Terraform + Ansible)

Équipe : Axel Malka, Mathéo Harison, Ambrine Zaouche, Raphaël Duflot

---

## 1. Contexte

Notre équipe joue le rôle d'une équipe DevSecOps en entreprise. Mission : concevoir, déployer et durcir une **infrastructure AWS sécurisée et 100% automatisée** avec Terraform et Ansible.

Le projet met en place :
- un **bastion** public pour l'accès SSH,
- un **Ansible master** public pour l'orchestration,
- un **serveur web privé** (`nginx`) sans IP publique,
- un **serveur FTP privé** (`vsftpd`) sans IP publique,
- des **best practices de sécurité** : Security Groups, NACL, hardening SSH, firewall hôte et mises à jour automatiques.

---

## 2. Structure du dépôt

```
projet-final/
|-- README.md                   ce fichier
|-- .gitignore                  exclut *.pem, terraform.tfstate, .terraform/
|-- Makefile                    make deploy / make destroy / make ping
|-- terraform/
|   |-- provider.tf             provider AWS + TLS + local
|   |-- variables.tf            variables Terraform
|   |-- main.tf                 point d'entrée — modules réseau, sécurité, compute
|   |-- outputs.tf              sorties Terraform utiles après apply
|   |-- terraform.tfvars        paramètres locaux (admin_ip, project)
|   `-- modules/
|       |-- network/            VPC, subnets public/privés, IGW, NAT Gateway, routes
|       |-- security/           Security Groups + NACL subnet privé
|       `-- compute/            EC2 bastion, Ansible master, web, FTP + clés SSH
`-- ansible/
    |-- ansible.cfg
    |-- site.yml                playbook principal (hardening, web, ftp)
    |-- inventory.tftpl         inventaire généré par Terraform
    |-- group_vars/
    |   `-- ftp.yml              mot de passe FTP et variables Ansible
    `-- roles/
        |-- webserver/          installe et configure nginx
        |-- ftpserver/          installe et configure vsftpd
        `-- hardening/          durcissement SSH, firewall et mises à jour auto
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

### 3.2 Configuration Ansible

- L'inventaire Ansible est généré automatiquement par Terraform dans `ansible/inventory.ini`.
- La clé privée SSH est créée par Terraform dans `terraform/tp-finale-key.pem`, puis copiée dans `ansible/tp-finale-key.pem` par `make deploy`.
- Le mot de passe FTP est défini dans `ansible/group_vars/ftp.yml` :
  ```yaml
  ftp_password: "Gr0upS1xFTP!"
  ```

---

## 4. Déploiement

### 4.1 Commande recommandée

```bash
make deploy
```

`make deploy` exécute :
1. Terraform (`init` + `apply`) dans `terraform/`
2. copie de la clé SSH vers `ansible/`
3. Ansible (`ansible-playbook -i inventory.ini site.yml`) dans `ansible/`
4. affichage des commandes de connexion SSH/tunnels utiles.

### 4.2 Vérifier la connectivité

```bash
make ping
```

### 4.3 Destruction et nettoyage

```bash
make destroy
```

Cette commande détruit l'infrastructure Terraform et supprime les fichiers générés (`ansible/inventory.ini`, clé SSH copiée).

> Important : vérifiez dans la console AWS qu'il ne reste aucun VPC, NAT Gateway, Elastic IP ou EC2, puis cliquez sur **End Lab**.

---

## 5. Choix d'architecture & justifications

### 5.1 Modules Terraform

- `terraform/modules/network` : VPC, subnets, IGW, NAT Gateway, tables de routage.
- `terraform/modules/security` : Security Groups et NACL pour le subnet privé.
- `terraform/modules/compute` : génération de la paire SSH et création des instances EC2.
- `terraform/main.tf` : assemble les modules et génère l'inventaire Ansible.

### 5.2 Réseau (`modules/network`)

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


### 5.3 Sécurité (`modules/security`)

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


### 5.4 Compute (`modules/compute`)

Le module `terraform/modules/compute` crée les instances EC2 et la paire SSH utilisée par Ansible :
- `tls_private_key` génère une clé RSA 4096 bits.
- `aws_key_pair` enregistre la clé publique sur AWS.
- `local_file` écrit la clé privée dans `terraform/tp-finale-key.pem`.
- `data.aws_ami.amazon_linux_2023` récupère l'AMI Amazon Linux 2023 la plus récente.
- `aws_instance.bastion` : bastion public dans le subnet public.
- `aws_instance.ansible_master` : Ansible master public dans le subnet public.
- `aws_instance.web` : serveur web privé dans le subnet privé A.
- `aws_instance.ftp` : serveur FTP privé dans le subnet privé B.

Chaque instance utilise le profil IAM `LabInstanceProfile` imposé par AWS Academy. Le bastion et l'Ansible master ont des adresses publiques, alors que le web et le FTP restent accessibles uniquement via le bastion / tunnel SSH.

---

## 6. Ansible

### 6.1 Playbook principal

`ansible/site.yml` exécute :
- `hardening` puis `webserver` sur le serveur web,
- `hardening` puis `ftpserver` sur le serveur FTP.

### 6.2 Rôles

- `roles/webserver` : installe et démarre `nginx`.
- `roles/ftpserver` : installe `vsftpd`, crée `ftpuser`, configure le partage et la plage passive, active le firewall local.
- `roles/hardening` : durcit SSH, configure `firewalld` et active les mises à jour automatiques.

### 6.3 Inventaire

L'inventaire `ansible/inventory.ini` est généré automatiquement par Terraform depuis `ansible/inventory.tftpl`.

Il contient les hôtes `bastion`, `web`, `ftp` et le groupe `private` pour la connexion via bastion.

---

## 7. Sorties Terraform

Terraform fournit les sorties suivantes :
- `bastion_public_ip`
- `ansible_master_public_ip`
- `web_private_ip`
- `ftp_private_ip`
- `ssh_key_path`
- commandes SSH recommandées pour se connecter au bastion et à l'Ansible master.

---

## 8. Nettoyage

```bash
make destroy
```

Vérifiez dans la console AWS qu'il ne reste aucune ressource résiduelle (EC2, NAT Gateway, Elastic IP, VPC), puis cliquez **End Lab**.