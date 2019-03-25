output "private_zone_id" {
  value = "${aws_route53_zone.pokedextracker_private.zone_id}"
}

output "public_zone_id" {
  value = "${aws_route53_zone.pokedextracker_public.zone_id}"
}
