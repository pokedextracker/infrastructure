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

  config = {
    bucket = "terraform.pokedextracker.com"
    key    = "dns.tfstate"
    region = "us-west-2"
  }
}

resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.pokedextracker.com"
  validation_method         = "DNS"
  subject_alternative_names = ["pokedextracker.com"]

  tags = {
    Name    = "wildcard-certificate"
    Project = "PokedexTracker"
  }
}


resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.terraform_remote_state.dns.outputs.zone_id
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
