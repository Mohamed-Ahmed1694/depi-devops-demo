terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Latest Ubuntu 24.04 LTS image published by Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# ---------------------------------------------------------------------------
# Network: our own small VPC, so the demo never depends on how the account's
# default VPC was changed. Internet -> Internet Gateway -> route -> public subnet.
# ---------------------------------------------------------------------------

# Pick an Availability Zone that offers the chosen instance type
data "aws_ec2_instance_type_offerings" "here" {
  location_type = "availability-zone"
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

resource "aws_vpc" "demo" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc", Project = var.project_name }
}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id
  tags   = { Name = "${var.project_name}-igw", Project = var.project_name }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.demo.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = sort(data.aws_ec2_instance_type_offerings.here.locations)[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public", Project = var.project_name }
}

# The line that makes the subnet "public": all traffic to the internet goes via the gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }
  tags = { Name = "${var.project_name}-public", Project = var.project_name }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Firewall + server
# ---------------------------------------------------------------------------
resource "aws_security_group" "demo" {
  name        = "${var.project_name}-sg"
  description = "DEPI DevOps demo - SSH, app, Jenkins (optional), Prometheus, Grafana"
  vpc_id      = aws_vpc.demo.id

  dynamic "ingress" {
    for_each = var.open_ports
    content {
      description = ingress.key
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = var.project_name }
}

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name # existing key pair (run-all.sh imports it first if missing)
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.demo.id]

  # Wait for the internet route before the server boots (cloud-init needs it)
  depends_on = [aws_route_table_association.public]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
  }
}

# Terraform hands over to Ansible: write the inventory file automatically
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content         = <<-EOT
    [demo]
    ${aws_instance.demo.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${var.private_key_path}

    [demo:vars]
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
}
