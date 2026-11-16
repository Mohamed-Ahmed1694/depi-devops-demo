# DEPI DevOps Demo - short commands.  Run: make help
IP = $$(cd terraform && terraform output -raw server_public_ip)
SSH = ssh -i ~/.ssh/depi-test.pem ubuntu@$(IP)

help: ## Show the commands
	@grep -E '^[a-z-]+:.*## ' Makefile | awk -F':.*## ' '{printf "  make %-11s %s\n", $$1, $$2}'

all: ## Do EVERYTHING: EC2 + setup + GitHub + pipeline
	./scripts/run-all.sh

check: ## Which tools are installed
	./scripts/check-tools.sh

test: ## Unit tests
	python3 -m venv .venv && .venv/bin/pip install -q -r app/requirements.txt
	cd app && ../.venv/bin/pytest -v

local-up: ## Run app + Prometheus + Grafana on your laptop
	docker compose up -d --build
	@echo "App http://localhost:5000 | Prometheus http://localhost:9090 | Grafana http://localhost:3000"

local-down: ## Stop the laptop version
	docker compose down

configure: ## Re-run Ansible on the server
	cd ansible && ansible-playbook site.yml

jenkins: ## Install Jenkins on the server (optional lesson, port 8080)
	cd ansible && ansible-playbook site.yml -e install_jenkins=true

ssh: ## Log in to the server
	$(SSH)

status: ## Show the pods on the server
	$(SSH) 'sudo k3s kubectl get pods -A'

doctor: ## Find why SSH/Ansible can't reach the server (read-only)
	./scripts/doctor.sh

aws-check: ## List anything in AWS that costs money, in every region (read-only)
	./scripts/aws-check.sh

destroy: ## DELETE the EC2 (do this after the lesson!)
	cd terraform && terraform destroy

.PHONY: help all check test local-up local-down configure jenkins ssh status doctor aws-check destroy
