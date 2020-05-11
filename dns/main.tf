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

locals {
  # change this if the ELB is ever recreated
  ingress_elb_name = "a5289339bf4a64bfcb32a1514094cc1a"
}

data "aws_elb" "ingress_elb" {
  name = "${local.ingress_elb_name}"
}

resource "aws_route53_zone" "pokedextracker" {
  name    = "pokedextracker.com"
  comment = "Managed by pokedextracker/infrastructure"

  tags {
    Name    = "pokedextracker.com"
    Project = "PokedexTracker"
  }
}

resource "aws_route53_record" "apex_txt" {
  zone_id = "${aws_route53_zone.pokedextracker.zone_id}"
  name    = ""
  type    = "TXT"
  ttl     = "300"

  records = [
    "google-site-verification=oRcez-HTVRL5X6j81zqLNDw6P-98jrAGsvdDjwg6PmA",
    "v=spf1 include:spf.efwd.registrar-servers.com ~all",
  ]
}

resource "aws_route53_record" "apex" {
  zone_id         = "${aws_route53_zone.pokedextracker.zone_id}"
  name            = ""
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = "${data.aws_elb.ingress_elb.dns_name}"
    zone_id                = "${data.aws_elb.ingress_elb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id         = "${aws_route53_zone.pokedextracker.zone_id}"
  name            = "www"
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = "${data.aws_elb.ingress_elb.dns_name}"
    zone_id                = "${data.aws_elb.ingress_elb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "staging" {
  zone_id         = "${aws_route53_zone.pokedextracker.zone_id}"
  name            = "staging"
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = "${data.aws_elb.ingress_elb.dns_name}"
    zone_id                = "${data.aws_elb.ingress_elb.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "staging_www" {
  zone_id         = "${aws_route53_zone.pokedextracker.zone_id}"
  name            = "www.staging"
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = "${data.aws_elb.ingress_elb.dns_name}"
    zone_id                = "${data.aws_elb.ingress_elb.zone_id}"
    evaluate_target_health = false
  }
}
