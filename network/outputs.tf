output "availability_zones" {
  value = "${data.aws_availability_zones.available.names}"
}

output "cidr_block" {
  value = "${local.cidr_block}"
}

output "private_subnets" {
  value = "${aws_subnet.private.*.id}"
}

output "public_subnets" {
  value = "${aws_subnet.public.*.id}"
}

output "vpc_id" {
  value = "${aws_vpc.main.id}"
}
