terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "terraform_bucket.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "terraform" {
  bucket = "terraform.pokedextracker.com"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags {
    Project = "PokedexTracker"
  }
}
