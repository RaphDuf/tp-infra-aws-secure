# =============================================================
# Makefile — Déploiement infrastructure AWS sécurisée
# Usage : make deploy | make destroy | make ping
# =============================================================

TERRAFORM_DIR := terraform
ANSIBLE_DIR   := ansible
KEY_NAME      := tp-finale-key.pem

.PHONY: deploy destroy ping help

help:
	@echo ""
	@echo "Commandes disponibles :"
	@echo "  make deploy   — Déploie l'infra + configure les serveurs"
	@echo "  make destroy  — Détruit toute l'infrastructure"
	@echo "  make ping     — Teste la connectivité Ansible"
	@echo ""

# =============================================================
# DEPLOY — infra + config complète
# =============================================================
deploy: tf-apply copy-key ansible-run show-info

tf-apply:
	@echo "\n[1/4] Déploiement Terraform..."
	cd $(TERRAFORM_DIR) && terraform init -upgrade && terraform apply -auto-approve

copy-key:
	@echo "\n[2/4] Copie de la clé SSH dans le dossier Ansible..."
	cp $(TERRAFORM_DIR)/$(KEY_NAME) $(ANSIBLE_DIR)/$(KEY_NAME)
	chmod 400 $(ANSIBLE_DIR)/$(KEY_NAME)

ansible-run:
	@echo "\n[3/4] Configuration des serveurs avec Ansible..."
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.ini site.yml

show-info:
	@echo "\n[4/4] Infrastructure déployée ! Infos de connexion :"
	@echo "-----------------------------------------------------"
	@echo "Bastion (entrée SSH) :"
	@echo "  ssh -i $(ANSIBLE_DIR)/$(KEY_NAME) ec2-user@$$(cd $(TERRAFORM_DIR) && terraform output -raw bastion_public_ip)"
	@echo ""
	@echo "Ansible Master :"
	@echo "  ssh -i $(ANSIBLE_DIR)/$(KEY_NAME) -o ProxyCommand=\"ssh -i $(ANSIBLE_DIR)/$(KEY_NAME) -o StrictHostKeyChecking=no -W %h:%p ec2-user@$$(cd $(TERRAFORM_DIR) && terraform output -raw bastion_public_ip)\" ec2-user@$$(cd $(TERRAFORM_DIR) && terraform output -raw ansible_master_private_ip)"
	@echo ""
	@echo "Serveur Web (tunnel nginx) :"
	@echo "  ssh -i $(ANSIBLE_DIR)/$(KEY_NAME) -o ProxyCommand=\"ssh -i $(ANSIBLE_DIR)/$(KEY_NAME) -o StrictHostKeyChecking=no -W %h:%p ec2-user@$$(cd $(TERRAFORM_DIR) && terraform output -raw bastion_public_ip)\" -L 8080:localhost:80 ec2-user@$$(cd $(TERRAFORM_DIR) && terraform output -raw web_private_ip)"
	@echo "  puis : curl http://localhost:8080"
	@echo ""
	@echo "Serveur FTP (tunnel vsftpd) :"
	@echo "  ssh -i $(ANSIBLE_DIR)/$(KEY_NAME) -o ProxyCommand=\"ssh -i $(ANSIBLE_DIR)/$(KEY_NAME) -o StrictHostKeyChecking=no -W %h:%p ec2-user@$$(cd $(TERRAFORM_DIR) && terraform output -raw bastion_public_ip)\" -L 2121:localhost:21 ec2-user@$$(cd $(TERRAFORM_DIR) && terraform output -raw ftp_private_ip)"
	@echo "  puis : ftp localhost 2121"
	@echo "-----------------------------------------------------"

# =============================================================
# PING — teste la connectivité Ansible
# =============================================================
ping:
	@echo "\nTest de connectivité Ansible..."
	cd $(ANSIBLE_DIR) && ansible all -i inventory.ini -m ping

# =============================================================
# DESTROY — destruction propre
# =============================================================
destroy:
	@echo "\nDestruction de l'infrastructure..."
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve
	@echo "Nettoyage des fichiers générés..."
	rm -f $(ANSIBLE_DIR)/$(KEY_NAME)
	rm -f $(ANSIBLE_DIR)/inventory.ini
	@echo "Infrastructure détruite. Pensez à cliquer End Lab sur AWS Academy."