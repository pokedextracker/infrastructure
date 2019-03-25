terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "kubernetes.tfstate"
    region  = "us-west-2"
  }
}

locals {
  allowed_cidr_blocks = ["136.24.25.248/32"]
  kubernetes_version  = "1.13.4"
  name                = "pokedextracker"
  pod_subnet          = "192.168.0.0/16"
  service_subnet      = "192.168.20.0/16"
}

data "aws_region" "current" {}

data "terraform_remote_state" "dns" {
  backend = "s3"

  config {
    bucket = "terraform.pokedextracker.com"
    key    = "dns.tfstate"
    region = "us-west-2"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config {
    bucket = "terraform.pokedextracker.com"
    key    = "network.tfstate"
    region = "us-west-2"
  }
}

data "aws_subnet" "public" {
  id = "${data.terraform_remote_state.network.public_subnets.0}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "kubernetes" {
  key_name   = "${local.name}-kubernetes"
  public_key = "${file("pokedextracker-kubernetes.pub")}"
}

resource "aws_kms_key" "kubernetes" {
  description             = "${local.name}-kubernetes"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  is_enabled              = true

  tags {
    Name    = "${local.name}-kubernetes"
    Project = "PokedexTracker"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_kms_alias" "kubernetes" {
  name          = "alias/${local.name}-kubernetes"
  target_key_id = "${aws_kms_key.kubernetes.id}"
}
