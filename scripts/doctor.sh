#!/usr/bin/env bash
# Read-only checks for when Ansible / SSH cannot reach the server.   Run:  make doctor
# It changes nothing. Copy the whole output when you ask for help.
cd "$(dirname "$0")/.." || exit 1
KEY="$HOME/.ssh/depi-test.pem"
say() { printf "\n==== %s ====\n" "$*"; }

say "1. Terraform"
IP="$(cd terraform && terraform output -raw server_public_ip 2>/dev/null)"
ID="$(cd terraform && terraform output -raw instance_id 2>/dev/null)"
[ -n "$ID" ] || ID="$(aws ec2 describe-instances --filters Name=tag:Name,Values=depi-devops-demo-server \
  Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)"
echo "region: $(aws configure get region)   instance: $ID   IP from Terraform: $IP"

say "2. Instance"
aws ec2 describe-instances --instance-ids "$ID" --output text --query \
  'Reservations[].Instances[].[State.Name,InstanceType,PublicIpAddress,KeyName,SubnetId,VpcId]'
SG="$(aws ec2 describe-instances --instance-ids "$ID" --output text --query 'Reservations[].Instances[].SecurityGroups[].GroupId')"
SUBNET="$(aws ec2 describe-instances --instance-ids "$ID" --output text --query 'Reservations[].Instances[].SubnetId')"
VPC="$(aws ec2 describe-instances --instance-ids "$ID" --output text --query 'Reservations[].Instances[].VpcId')"

say "3. Health checks (system / instance)"
aws ec2 describe-instance-status --instance-ids "$ID" --output text \
  --query 'InstanceStatuses[].[SystemStatus.Status,InstanceStatus.Status]'

say "4. Security group $SG - inbound rules (port, from)"
aws ec2 describe-security-groups --group-ids $SG --output text \
  --query 'SecurityGroups[].IpPermissions[].[FromPort,join(`,`,IpRanges[].CidrIp)]'

say "5. Routes in $VPC (need a line: 0.0.0.0/0  igw-...)"
aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC" --output text \
  --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId]'
echo "subnet of the server: $SUBNET  (public IP on launch: $(aws ec2 describe-subnets --subnet-ids "$SUBNET" --output text --query 'Subnets[].MapPublicIpOnLaunch'))"

say "6. Network ACL inbound rules (rule, protocol, port, from, action)"
aws ec2 describe-network-acls --filters Name=vpc-id,Values="$VPC" --output text \
  --query 'NetworkAcls[].Entries[?Egress==`false`].[RuleNumber,Protocol,PortRange.From,CidrBlock,RuleAction]'

say "7. Your laptop"
echo "public IP: $(curl -s -m 5 https://checkip.amazonaws.com)"
ls -l "$KEY" 2>&1
echo "local .pem fingerprints (one of them must match AWS below):"
openssl pkey -in "$KEY" -pubout -outform DER 2>/dev/null | openssl md5 -c        # key imported into AWS
openssl pkcs8 -in "$KEY" -topk8 -nocrypt -outform DER 2>/dev/null | openssl sha1 -c # key created by AWS
echo "key fingerprint in AWS:"
aws ec2 describe-key-pairs --key-names depi-test --output text --query 'KeyPairs[].[KeyName,KeyFingerprint,KeyType]' 2>&1

say "8. SSH to GitHub (does your network allow port 22 at all?)"
ssh -T -o ConnectTimeout=8 -o BatchMode=yes -o StrictHostKeyChecking=no git@github.com 2>&1 | head -2

say "9. SSH to the server"
ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -i "$KEY" ubuntu@"$IP" 'echo SSH OK; uptime' 2>&1 | tail -3

say "10. Server boot log (last 25 lines)"
aws ec2 get-console-output --instance-id "$ID" --latest --output text --query Output 2>/dev/null | tail -25 \
  || aws ec2 get-console-output --instance-id "$ID" --output text --query Output | tail -25

echo; echo "Done. Copy everything above."
