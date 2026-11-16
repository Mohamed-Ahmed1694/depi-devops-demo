#!/usr/bin/env bash
# Read-only: lists AWS resources that cost money, in EVERY region. Deletes nothing.
#   Run:  make aws-check      (after make destroy, every region should say "clean")
# Free and normal, so not listed: the default VPC of each region, key pairs, empty security groups.
found=0
for r in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
  # Some organizations block regions (service control policy). Nothing can exist there, so skip them.
  if ! err="$(aws ec2 describe-vpcs --region "$r" --max-results 5 --output text 2>&1 >/dev/null)"; then
    case "$err" in
      *UnauthorizedOperation*|*AuthFailure*|*OptInRequired*) echo "== $r: skipped (blocked for your user)"; continue ;;
      *) echo "== $r: ERROR $err"; found=1; continue ;;
    esac
  fi
  out="$(
    aws ec2 describe-instances --region "$r" --output text \
      --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
      --query 'Reservations[].Instances[].[`"EC2 server"`,InstanceId,State.Name,InstanceType]'
    aws ec2 describe-volumes --region "$r" --output text --query 'Volumes[].[`"Disk (EBS)"`,VolumeId,State,Size]'
    aws ec2 describe-snapshots --region "$r" --owner-ids self --output text --query 'Snapshots[].[`"Snapshot"`,SnapshotId]'
    aws ec2 describe-addresses --region "$r" --output text --query 'Addresses[].[`"Elastic IP"`,PublicIp]'
    aws ec2 describe-nat-gateways --region "$r" --output text \
      --filter Name=state,Values=pending,available --query 'NatGateways[].[`"NAT gateway"`,NatGatewayId]'
    aws elbv2 describe-load-balancers --region "$r" --output text --query 'LoadBalancers[].[`"Load balancer"`,LoadBalancerName]' 2>/dev/null
    aws ec2 describe-vpcs --region "$r" --output text --filters Name=is-default,Values=false \
      --query 'Vpcs[].[`"Extra VPC (free, but check it)"`,VpcId,CidrBlock]'
  )"
  if [ -n "$out" ]; then echo "== $r"; echo "$out"; found=1; else echo "== $r: clean"; fi
done
echo
[ $found -eq 0 ] && echo "✅ Nothing found in any region." || echo "⚠️  Something is still there - see above."
