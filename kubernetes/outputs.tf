output "cert_manager_iam_role_name" {
  value = "${aws_iam_role.cert_manager.arn}"
}
