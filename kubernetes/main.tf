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
