variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefix used for all resource names"
  type        = string
  default     = "depi-devops-demo"
}

variable "instance_type" {
  description = "EC2 size. t3.medium (2 vCPU / 4 GB) is the minimum for K3s + Jenkins + monitoring"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair in this region (you hold its .pem file)"
  type        = string
  default     = "depi-test"
}

variable "private_key_path" {
  description = "Path to your SSH private key (written into the Ansible inventory)"
  type        = string
  default     = "~/.ssh/depi-test.pem"
}

variable "allowed_cidr" {
  description = "Who may reach the server. Use your own IP, e.g. 41.x.x.x/32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "open_ports" {
  description = "Ports opened on the security group"
  type        = map(number)
  default = {
    ssh        = 22
    jenkins    = 8080
    app        = 30080
    prometheus = 30090
    grafana    = 30030
  }
}
