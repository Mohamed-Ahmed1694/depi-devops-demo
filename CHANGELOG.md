# Changelog

## v2.0.2 — 2026-11-16 — Key pair "Duplicate" error
**Fixed**
- `make all` failed with `InvalidKeyPair.Duplicate: The keypair already exists`. The script's check `aws ec2 describe-key-pairs` failed even though `depi-test` existed, so it told Terraform to import the key again. Terraform no longer manages the key pair at all (removed `aws_key_pair.imported` and `var.public_key`). The script imports `depi-test` with the AWS CLI only if it is missing, and just continues if AWS says it already exists.
- Running `make all` again without `TF_VAR_instance_type` would have switched the server back to t3.medium (Terraform replaces the server, and the Free plan refuses t3.medium). The script now saves `instance_type` in `terraform/terraform.tfvars` and reuses it on later runs.

**Tested**: the key/instance-type step with a fake `aws` CLI in 5 cases (key exists; TF_VAR set; rerun remembers type; key missing → import; import says Duplicate → continue). `shellcheck`, `terraform fmt` passed. `terraform validate` runs in CI.

## v2.0.1 — 2026-11-16 — Ansible install on Intel Macs, AWS Free plan
**Fixed**
- First real `make all` failed at `aws_instance.demo`: `InvalidParameterCombination: The specified instance type is not eligible for Free Tier`. AWS accounts on the Free plan can only launch free-tier-eligible types, and t3.medium is not one. Documented the fix in the README: list eligible types, then `TF_VAR_instance_type=<type> make all` (2 vCPU / 4 GB or more), or upgrade the account. The security group created before the error stays in the Terraform state and is reused.
- `brew install ansible` hangs for hours on Intel Macs: Homebrew no longer builds bottles for macOS x86_64, so it compiles LLVM and Rust from source. README step 0 now installs `ansible-core` with pip in `~/.ansible-venv` (prebuilt wheels, about 1 minute). The playbook only uses `ansible.builtin` modules, so `ansible-core` is enough.
- `run-all.sh` "tool missing" message points to README step 0 instead of `brew install ansible`.

**Added**
- `docs/TEACHING-GUIDE.md`: architecture, one-sentence explanation per tool, a 10-step check list after `make all`, a 45-minute live demo script (live change, failing test, self-healing, scaling, rollback, monitoring, cleanup) and student exercises. Linked from the README.

## v2.0.0 — 2026-11-16 — GitHub Actions CI/CD + one command
**Problems found (diagnosis)**
- The GitHub repo had only the old Jenkins version (1 commit). `.github/workflows/`, `Makefile`, `scripts/run-all.sh` and `scripts/deploy-on-server.sh` did not exist, although the README pointed to them. GitHub Actions had never run (0 runs).
- `ansible/inventory.ini` was committed. Terraform overwrites it with the server IP, so the IP could get committed by mistake.
- Terraform had no fix for "key pair `depi-test` not in this region", and the region was hard-coded (`eu-central-1`).
- Ansible started installing packages straight away. On a new EC2, cloud-init holds the apt lock, so it could fail.

**Added**
- `.github/workflows/ci-cd.yml`: 1 test (pytest) ➜ 2 build (docker build + run + `/health`) ➜ 3 IaC check (terraform fmt/validate, ansible syntax-check, kubeconform) ➜ 4 deploy (push to `main` only: rsync to `/opt/depi-demo`, run `deploy-on-server.sh <run_number>`, smoke test fails unless `/api` returns `"version":"<run_number>"`, links in the job summary).
- `scripts/run-all.sh`: one simple script with 8 numbered steps (tools ➜ logins ➜ key ➜ Terraform (asks "yes") ➜ Ansible ➜ GitHub ➜ push + watch ➜ links).
- `scripts/deploy-on-server.sh`: docker build ➜ `k3s ctr images import` ➜ kubectl apply ➜ rollout status ➜ monitoring.
- `Makefile`: help, all, check, test, local-up, local-down, configure, ssh, status, destroy.
- `ansible/inventory.ini.example`.

**Changed**
- CI/CD is now GitHub Actions. Jenkins is optional (`install_jenkins: false`); the `Jenkinsfile` is kept as an extra lesson.
- `EC2_HOST` is a GitHub **variable**, not a secret. GitHub prints secrets as `***` in logs, so the links would be unreadable. `EC2_SSH_KEY` stays a secret.
- Terraform: `aws_region` has no default (the script takes it from `aws configure get region`). New `public_key` variable: if `depi-test` is missing in the region, Terraform imports it from your `.pem`.
- Ansible: waits for SSH and cloud-init, creates `/opt/depi-demo` owned by `ubuntu` (so Actions can rsync), copies app/k8s/scripts and does the first deploy (version `ansible`).
- App page: "Version (GitHub Actions run)"; the stack list shows GitHub Actions instead of Jenkins.
- `check-tools.sh`: gh, python3 and ssh-keygen required; on the server, Jenkins is optional and demo-app is checked.
- README rewritten: short, step by step, with the architecture diagram.
- `ansible/inventory.ini` is git-ignored (written by Terraform).

**Tested (in a Linux cloud container, not on the Mac)**
- `make test`: 4/4 passed.
- Local stack: `/api` returns the new text; Prometheus target `demo-app` is UP; Grafana dashboard "DEPI Demo App" loads and reads from Prometheus. (The image was built with the sandbox proxy certificate added. That change is not in the repo.)
- `terraform fmt -check`: passed. `ansible-playbook --syntax-check`: passed. kubeconform: 15/15 valid. `bash -n` on all scripts: passed.

**Not tested yet**
- `terraform validate`: the sandbox blocks the Terraform registry. CI job 3 runs it.
- AWS, Ansible against a real EC2, the deploy job, `run-all.sh` on macOS. These need your laptop and AWS account.

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
