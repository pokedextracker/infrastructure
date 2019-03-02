terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "kubernetes.tfstate"
    region  = "us-west-2"
  }
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

# This was generated with the follow command and then slightly modified.

# kops create cluster \
#   --admin-access 136.24.25.248/32 \
#   --api-loadbalancer-type public \
#   --associate-public-ip \
#   --authorization RBAC \
#   --cloud aws \
#   --cloud-labels Project=PokedexTracker \
#   --dns public \
#   --encrypt-etcd-storage \
#   --image kope.io/k8s-1.9-debian-stretch-amd64-hvm-ebs-2018-05-27 \
#   --kubernetes-version 1.10.5 \
#   --master-public-name k8s.pokedextracker.com \
#   --master-size t2.micro \
#   --master-tenancy default \
#   --master-volume-size 16 \
#   --master-zones us-west-2a,us-west-2b \
#   --name k8s.pokedextracker.com \
#   --networking calico \
#   --node-count 4 \
#   --node-size t2.micro \
#   --node-tenancy default \
#   --node-volume-size 32 \
#   --out . \
#   --ssh-access 136.24.25.248/32 \
#   --ssh-public-key ~/.ssh/pokedextracker-kubernetes.pub \
#   --state s3://kops-state.pokedextracker.com \
#   --subnets subnet-396b675f,subnet-28cce060,subnet-481be212 \
#   --target terraform \
#   --utility-subnets subnet-396b675f,subnet-28cce060,subnet-481be212 \
#   --vpc vpc-587db021 \
#   --zones us-west-2a,us-west-2b,us-west-2c

# Modifications include:
# - None

resource "aws_s3_bucket" "kops_state" {
  bucket = "kops-state.pokedextracker.com"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags {
    Project = "PokedexTracker"
  }
}
