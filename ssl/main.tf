terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "ssl.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

data "terraform_remote_state" "dns" {
  backend = "s3"

  config {
    bucket = "terraform.pokedextracker.com"
    key    = "dns.tfstate"
    region = "us-west-2"
  }
}

resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.pokedextracker.com"
  validation_method         = "DNS"
  subject_alternative_names = ["pokedextracker.com"]

  tags {
    Name    = "wildcard-certificate"
    Project = "PokedexTracker"
  }
}

resource "aws_route53_record" "validation" {
  name    = "${aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.terraform_remote_state.dns.zone_id}"
  records = ["${aws_acm_certificate.wildcard.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = "${aws_acm_certificate.wildcard.arn}"
  validation_record_fqdns = ["${aws_route53_record.validation.fqdn}"]
}
