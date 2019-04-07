output "account_id" {
  value = "${data.aws_caller_identity.current.account_id}"
}

output "cluster_endpoint" {
  value = "${aws_route53_record.k8s.fqdn}"
}

output "kube2iam_iam_path" {
  value = "${local.kube2iam_iam_path}"
}

output "master_ip" {
  value = "${aws_eip.master.public_ip}"
}
