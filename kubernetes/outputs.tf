output "cluster_endpoint" {
  value = "${aws_route53_record.k8s_public.fqdn}"
}

output "master_ip" {
  value = "${aws_eip.master.public_ip}"
}
