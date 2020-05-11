terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "kubernetes.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

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

# To get the latest one, run the following:
# aws ec2 describe-images --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*' | jq -r '.Images | sort_by(.CreationDate) | reverse[] | .Name' | head -n 1
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20200408"]
  }

  owners = ["099720109477"] # Canonical
}

# command to create new key pair:
# ssh-keygen -t rsa -f ~/.ssh/pokedextracker-kubernetes -P '' -C pokedextracker-kubernetes
resource "aws_key_pair" "kubernetes" {
  key_name   = "pokedextracker-kubernetes"
  public_key = "${file("pokedextracker-kubernetes.pub")}"
}

module "cluster_blue" {
  source = "../modules/kubernetes_cluster"

  allowed_cidr_blocks = ["136.24.147.41/32"]
  ami_id              = "${data.aws_ami.ubuntu.id}"
  dns_zone_id         = "${data.terraform_remote_state.dns.zone_id}"
  key_name            = "${aws_key_pair.kubernetes.key_name}"
  kubernetes_version  = "1.18.2"
  master_count        = 1
  name                = "pokedextracker"
  subnet_id           = "${data.terraform_remote_state.network.public_subnets.0}"
  worker_count        = 1
}
