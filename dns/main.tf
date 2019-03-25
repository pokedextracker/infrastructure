terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "dns.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config {
    bucket = "terraform.pokedextracker.com"
    key    = "network.tfstate"
    region = "us-west-2"
  }
}

resource "aws_route53_zone" "pokedextracker_public" {
  name    = "pokedextracker.com"
  comment = "Managed by pokedextracker/infrastructure"

  tags {
    Name       = "pokedextracker.com"
    Project    = "PokedexTracker"
    Visibility = "public"
  }
}

resource "aws_route53_zone" "pokedextracker_private" {
  name    = "pokedextracker.com"
  comment = "Managed by pokedextracker/infrastructure"

  vpc {
    vpc_id = "${data.terraform_remote_state.network.vpc_id}"
  }

  tags {
    Name       = "pokedextracker.com"
    Project    = "PokedexTracker"
    Visibility = "private"
  }
}

resource "aws_route53_record" "apex_txt" {
  zone_id = "${aws_route53_zone.pokedextracker_public.zone_id}"
  name    = ""
  type    = "TXT"
  ttl     = "300"

  records = [
    "google-site-verification=oRcez-HTVRL5X6j81zqLNDw6P-98jrAGsvdDjwg6PmA",
    "v=spf1 include:spf.efwd.registrar-servers.com ~all",
  ]
}

# TODO: make private copies of everything

resource "aws_route53_record" "apex" {
  zone_id = "${aws_route53_zone.pokedextracker_public.zone_id}"
  name    = ""
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "api" {
  zone_id = "${aws_route53_zone.pokedextracker_public.zone_id}"
  name    = "api"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "staging" {
  zone_id = "${aws_route53_zone.pokedextracker_public.zone_id}"
  name    = "staging"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "staging_api" {
  zone_id = "${aws_route53_zone.pokedextracker_public.zone_id}"
  name    = "staging.api"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "www" {
  zone_id = "${aws_route53_zone.pokedextracker_public.zone_id}"
  name    = "www"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}
