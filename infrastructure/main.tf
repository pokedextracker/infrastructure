terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "infrastructure.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

data "terraform_remote_state" "terraform" {
  backend = "s3"

  config {
    bucket = "terraform.pokedextracker.com"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}

data "aws_iam_policy_document" "ci" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = ["${data.terraform_remote_state.terraform.arn}"]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.terraform_remote_state.terraform.arn}/*"]
  }
}

resource "aws_iam_user" "ci" {
  name = "infrastructure-ci"
}

resource "aws_iam_access_key" "ci" {
  user = "${aws_iam_user.ci.name}"
}

resource "aws_iam_user_policy" "ci" {
  name   = "CIPolicy"
  user   = "${aws_iam_user.ci.name}"
  policy = "${data.aws_iam_policy_document.ci.json}"
}
