output "cert_manager_iam_role_name" {
  value = "${aws_iam_role.cert_manager.name}"
}

output "cluster_endpoint" {
  value = "${local.cluster_endpoint}"
}

output "kube2iam_iam_path" {
  value = "${local.kube2iam_iam_path}"
}
