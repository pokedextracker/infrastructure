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
  zone_id = "${aws_route53_zone.pokedextracker.zone_id}"
  name    = ""
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "api" {
  zone_id = "${aws_route53_zone.pokedextracker.zone_id}"
  name    = "api"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "staging" {
  zone_id = "${aws_route53_zone.pokedextracker.zone_id}"
  name    = "staging"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "staging_api" {
  zone_id = "${aws_route53_zone.pokedextracker.zone_id}"
  name    = "staging.api"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}

resource "aws_route53_record" "www" {
  zone_id = "${aws_route53_zone.pokedextracker.zone_id}"
  name    = "www"
  type    = "A"
  ttl     = "300"
  records = ["54.213.237.226"]
}
