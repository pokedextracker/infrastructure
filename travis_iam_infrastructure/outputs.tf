output "id" {
  value = "${aws_iam_access_key.travis.id}"
}

output "secret" {
  value = "${aws_iam_access_key.travis.secret}"
}
