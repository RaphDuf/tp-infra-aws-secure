# Projet final - Architecture AWS automatisee & securisee (Terraform + Ansible)

Equipe : .......................................................

## 1. Contexte
Votre equipe (4-5) joue le role d'une equipe DevSecOps en entreprise. Mission : concevoir
et deployer une **infrastructure AWS securisee, supervisee et 100% automatisee** :
un bastion + un Ansible master, des serveurs web prives, et un serveur de supervision.

## 2. Ce que contient ce starter
    projet-final-starter/
    |-- README.md                ce fichier
    |-- .gitignore
    |-- terraform/
    |   |-- provider.tf          aws ~>6, tls, local
    |   |-- variables.tf         region, project, my_ip
    |   |-- main.tf              point d'entree (appelle le module network) - A ETENDRE
    |   |-- outputs.tf
    |   |-- terraform.tfvars     renseignez votre IP publique
    |   `-- modules/
    |       `-- network/         VPC + 1 subnet public minimal - A ETENDRE
    `-- ansible/
        |-- ansible.cfg
        |-- site.yml             squelette (groupes web + supervision) - A ETENDRE
        |-- inventory.tftpl      gabarit d'inventaire (rempli par Terraform)
        `-- roles/
            `-- webserver/        installe nginx - A ETENDRE

Le socle est volontairement minimal : il **demarre**, il ne **fait pas tout**. A vous de batir le reste.

## 3. Prerequis AWS Academy
- Start Lab (voyant vert), puis collez vos identifiants (AWS Details -> AWS CLI : Show) dans `~/.aws/credentials`.
- Region us-east-1, instances t3.micro, AMI Amazon Linux 2023, profil `LabInstanceProfile` (pas de creation IAM).
- Les identifiants expirent quand le lab s'arrete : reactualisez-les apres chaque Start Lab.

## 4. Deploiement  (>>> A COMPLETER PAR VOUS <<<)
Le **resultat** est impose, pas le moyen : tout doit se deployer de facon **reproductible**
et se detruire proprement. Documentez ici VOTRE procedure (Makefile, script, ou commandes) :

    # exemple a adapter :
    cd terraform && terraform init && terraform apply
    cd ../ansible && ansible-playbook site.yml
    # destruction :
    cd terraform && terraform destroy

## 5. Choix d'architecture & justifications  (>>> A REMPLIR <<<)
Expliquez en quelques points vos decisions et ce que vous recommanderiez en entreprise :
- ...
- ...

## 6. Nettoyage
`terraform destroy` doit tout supprimer (verifiez : aucune EC2, NAT, VPC residuels), puis End Lab.
