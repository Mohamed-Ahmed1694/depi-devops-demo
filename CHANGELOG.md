# Changelog

## v1.0.0 — 2026-11-16 — Initial demo project
**Added**
- Flask app with an HTML home page, `/api`, `/health` and Prometheus `/metrics`, plus 4 pytest tests and a Dockerfile (non-root user).
- `docker-compose.yml` for a local stack (app + Prometheus + Grafana).
- Ansible playbook + roles (common, docker, k3s, jenkins) that set up an existing Ubuntu EC2, including the monitoring stack.
- K8s manifests: app (2 replicas, NodePort 30080) and monitoring (Prometheus 30090 with pod auto-discovery, Grafana 30030 with a pre-built dashboard).
- `Jenkinsfile`: test ➜ build ➜ import into K3s ➜ deploy ➜ smoke test, polling GitHub every 2 min.
- GitHub Actions CI: tests, Docker build/run check, `terraform fmt/validate`, Ansible syntax check, kubeconform.
- Optional Terraform for a new EC2 (uses the existing `depi-test` key pair, Ubuntu 24.04).
- `scripts/check-tools.sh`, `Makefile` (`make server IP=…`, `make deploy`, …), README.

**Fixed during build/verification**
- Gunicorn ran 2 workers, so each process kept separate Prometheus counters and `/metrics` was wrong. Now 1 worker + 4 threads.
- `kubectl --dry-run` needs a cluster, which CI runners don't have. Replaced with kubeconform.
- Jenkins apt key updated to `jenkins.io-2026.key` (the 2023 key expired 26 Mar 2026). Uses Java 21.
- Removed the unused Terraform variable `repo_url`.
- `*.pem` added to `.gitignore` so SSH keys are never committed.
