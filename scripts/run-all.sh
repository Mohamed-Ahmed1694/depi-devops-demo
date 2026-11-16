#!/usr/bin/env bash
# DEPI DevOps Demo - ONE script that does everything.   Run:  make all
#   1 tools  2 logins  3 SSH key  4 Terraform  5 Ansible  6 GitHub  7 push + watch  8 links
set -euo pipefail
cd "$(dirname "$0")/.."

KEY="$HOME/.ssh/depi-test.pem"
say() { printf "\n\033[1;34m==== %s ====\033[0m\n" "$*"; }
die() { printf "\033[0;31m❌ %s\033[0m\n" "$*"; exit 1; }

say "1. Tools"
for t in git gh terraform ansible-playbook aws ssh-keygen curl; do
  command -v "$t" >/dev/null || die "$t is missing. See README step 0 (Ansible: install with pip, not brew)"
done
echo "all tools found"

say "2. Log in to GitHub and AWS"
gh auth status >/dev/null 2>&1 || gh auth login -h github.com -p https -w -s workflow
gh api -i user | grep -i '^x-oauth-scopes:' | grep -q workflow || gh auth refresh -h github.com -s workflow
gh auth setup-git
aws sts get-caller-identity >/dev/null 2>&1 || aws configure
REGION="$(aws configure get region || true)"
[ -n "$REGION" ] || die "No AWS region. Run: aws configure set region <your-region>"
echo "GitHub user: $(gh api user -q .login) | AWS region: $REGION"

say "3. SSH key depi-test.pem"
[ -f "$KEY" ] || { mkdir -p ~/.ssh; cp ~/Downloads/depi-test.pem "$KEY" || die "depi-test.pem not in ~/.ssh or ~/Downloads"; }
chmod 400 "$KEY"
# Key pairs live in ONE region. Import depi-test from the .pem only if this region does not have it.
if aws ec2 describe-key-pairs --key-names depi-test >/dev/null 2>&1; then
  echo "key pair depi-test found in $REGION"
else
  ssh-keygen -y -f "$KEY" > "$HOME/.ssh/depi-test.pub"
  aws ec2 import-key-pair --key-name depi-test --public-key-material "fileb://$HOME/.ssh/depi-test.pub" >/dev/null \
    && echo "imported key pair depi-test into $REGION" \
    || echo "could not import depi-test (maybe it already exists) - continuing"
fi
# Remember the server size so a later run never changes it by accident.
# Free-plan AWS accounts: TF_VAR_instance_type=c7i-flex.large make all   (see README)
# Order: TF_VAR_instance_type > saved in tfvars > free-tier type with 2 vCPU / 4 GB+ > t3.medium
OLD_TYPE="$(sed -n 's/^instance_type *= *"\(.*\)"/\1/p' terraform/terraform.tfvars 2>/dev/null || true)"
TYPE="${TF_VAR_instance_type:-$OLD_TYPE}"
if [ -z "$TYPE" ]; then
  TYPE="$(aws ec2 describe-instance-types --output text \
    --filters Name=free-tier-eligible,Values=true Name=vcpu-info.default-vcpus,Values=2 \
              Name=processor-info.supported-architecture,Values=x86_64 \
    --query 'InstanceTypes[?MemoryInfo.SizeInMiB>=`4096`].InstanceType' 2>/dev/null \
    | tr '\t' '\n' | sort | head -1 || true)"
  TYPE="${TYPE:-t3.medium}"
fi
{ echo "aws_region       = \"$REGION\""
  echo "private_key_path = \"$KEY\""
  echo "instance_type    = \"$TYPE\""
} > terraform/terraform.tfvars
echo "using $KEY, server type $TYPE"

say "4. Terraform: create the EC2 server"
cd terraform
terraform init -input=false
terraform plan -input=false -out=tfplan
read -r -p "Create/update these AWS resources? It costs money per hour. Type yes: " ok
[ "$ok" = "yes" ] || die "Stopped. Nothing was created."
terraform apply -input=false tfplan
IP="$(terraform output -raw server_public_ip)"
cd ..
echo "server IP: $IP"

say "5. Ansible: install Docker + K3s + Prometheus + Grafana, start the app"
(cd ansible && ansible-playbook site.yml)

say "6. GitHub: repo + EC2_HOST + EC2_SSH_KEY"
git remote get-url origin >/dev/null 2>&1 || {
  git add -A; git commit -qm "DEPI DevOps demo" || true
  gh repo create "$(basename "$PWD")" --public --source . --remote origin
}
gh variable set EC2_HOST -b "$IP"
gh secret set EC2_SSH_KEY < "$KEY"

say "7. Push to main and watch GitHub Actions"
[ "$(git branch --show-current)" = "main" ] || die "Switch to main first: git checkout main"
git fetch -q origin main 2>/dev/null || true
git add -A
git commit -qm "Deploy from run-all.sh" || true
if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main 2>/dev/null || true)" ]; then
  gh workflow run ci-cd.yml --ref main      # nothing new to push: start the pipeline by hand
else
  git push -u origin main || die "Push refused. Run: git pull --rebase origin main   then: make all"
fi
sleep 10
gh run watch "$(gh run list -w ci-cd.yml -L 1 --json databaseId -q '.[0].databaseId')" --exit-status \
  || die "Pipeline failed. See the Actions tab or: gh run view --log-failed"

say "8. Done"
REPO="$(gh repo view --json url -q .url)"
cat <<EOF
Repo        $REPO
Actions     $REPO/actions
App         http://$IP:30080
Prometheus  http://$IP:30090
Grafana     http://$IP:30030   (admin / admin)

⚠️  After the lesson run:  make destroy   (the server costs money every hour)
EOF
