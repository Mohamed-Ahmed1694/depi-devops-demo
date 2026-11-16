#!/usr/bin/env bash
# Checks which DevOps tools are installed on THIS machine.
# Usage:  ./scripts/check-tools.sh            (your laptop: client tools)
#         ./scripts/check-tools.sh --server   (the EC2 server: server tools too)

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
missing=0

check() {  # check <label> <command> <version-cmd> [required|optional]
  local label=$1 cmd=$2 ver=$3 need=${4:-required}
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "${GREEN}✅ %-12s${NC} %s\n" "$label" "$(eval "$ver" 2>&1 | head -1)"
  elif [ "$need" = "optional" ]; then
    printf "${YELLOW}➖ %-12s${NC} not installed (optional)\n" "$label"
  else
    printf "${RED}❌ %-12s${NC} NOT installed\n" "$label"; missing=$((missing+1))
  fi
}

echo "== OS =="
uname -srm
[ -f /etc/os-release ] && grep PRETTY_NAME /etc/os-release | cut -d= -f2
[ "$(uname)" = "Darwin" ] && sw_vers | head -2
echo

echo "== Laptop / client tools =="
check Git        git        "git --version"
check GitHub-CLI gh         "gh --version" optional
check Terraform  terraform  "terraform version"
check Ansible    ansible    "ansible --version"
check AWS-CLI    aws        "aws --version"
check Docker     docker     "docker --version"
check kubectl    kubectl    "kubectl version --client"  optional
check curl       curl       "curl --version"

if [ "$1" = "--server" ]; then
  echo; echo "== Server tools =="
  check K3s     k3s    "k3s --version"
  systemctl is-active --quiet jenkins && printf "${GREEN}✅ %-12s${NC} service running\n" "Jenkins" \
    || printf "${RED}❌ %-12s${NC} service not running\n" "Jenkins"
  for svc in prometheus grafana; do
    if sudo k3s kubectl -n monitoring get deploy "$svc" >/dev/null 2>&1; then
      printf "${GREEN}✅ %-12s${NC} running in K3s (namespace monitoring)\n" "$svc"
    else
      printf "${RED}❌ %-12s${NC} not deployed\n" "$svc"; missing=$((missing+1))
    fi
  done
fi

echo
if command -v aws >/dev/null 2>&1; then
  echo "== AWS credentials =="
  aws sts get-caller-identity --query Arn --output text 2>/dev/null \
    && printf "${GREEN}✅ AWS credentials work${NC}\n" \
    || printf "${RED}❌ AWS credentials not configured (run: aws configure)${NC}\n"
fi
if command -v docker >/dev/null 2>&1; then
  docker info >/dev/null 2>&1 && printf "${GREEN}✅ Docker daemon running${NC}\n" \
    || printf "${RED}❌ Docker installed but daemon not running${NC}\n"
fi

echo
[ $missing -eq 0 ] && printf "${GREEN}All required tools found.${NC}\n" \
  || printf "${RED}%d required tool(s) missing - see README 'Install the tools'.${NC}\n" $missing
exit $missing
