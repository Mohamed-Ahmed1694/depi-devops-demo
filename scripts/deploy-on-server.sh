#!/usr/bin/env bash
# Runs ON THE SERVER. GitHub Actions calls it on every push:
#   bash /opt/depi-demo/scripts/deploy-on-server.sh <version>
set -euo pipefail
VERSION="$1"
cd /opt/depi-demo

echo "1. Build the Docker image (version $VERSION)"
sudo docker build --build-arg APP_VERSION="$VERSION" -t "depi-demo-app:$VERSION" app/

echo "2. Give the image to K3s (no registry needed)"
sudo docker save "depi-demo-app:$VERSION" | sudo k3s ctr images import -

echo "3. Deploy the new version to Kubernetes"
sed "s|depi-demo-app:latest|depi-demo-app:$VERSION|" k8s/app/app.yaml | sudo k3s kubectl apply -f -
sudo k3s kubectl -n demo rollout status deployment/demo-app --timeout=180s

echo "4. Deploy Prometheus + Grafana"
sudo k3s kubectl apply -k k8s/monitoring

sudo docker image prune -f
sudo k3s kubectl -n demo get pods
