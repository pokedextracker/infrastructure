output "account_id" {
  value = "${data.aws_caller_identity.current.account_id}"
}

output "cert_manager_iam_role_name" {
  value = "${module.cluster_blue.cert_manager_iam_role_name}"
}

output "cluster_endpoint" {
  value = "${module.cluster_blue.cluster_endpoint}"
}

output "kube2iam_iam_path" {
  value = "${module.cluster_blue.kube2iam_iam_path}"
}
