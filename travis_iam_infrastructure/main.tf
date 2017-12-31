terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "travis_iam_infrastructure.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

data "terraform_remote_state" "terraform_bucket" {
  backend = "s3"

  config {
    bucket = "terraform.pokedextracker.com"
    key    = "terraform_bucket.tfstate"
    region = "us-west-2"
  }
}

data "aws_iam_policy_document" "travis" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = ["${data.terraform_remote_state.terraform_bucket.arn}"]
  }

  statement {
    actions = ["s3:GetObject"]

    resources = ["${data.terraform_remote_state.terraform_bucket.arn}/*"]
  }
}

resource "aws_iam_user" "travis" {
  name = "travis-infrastructure"
}

resource "aws_iam_access_key" "travis" {
  user = "${aws_iam_user.travis.name}"
}

resource "aws_iam_user_policy" "travis" {
  name = "TravisPolicy"
  user = "${aws_iam_user.travis.name}"

  policy = "${data.aws_iam_policy_document.travis.json}"
}
