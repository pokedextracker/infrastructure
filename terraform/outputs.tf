output "arn" {
  value = "${aws_s3_bucket.terraform.arn}"
}

output "bucket_domain_name" {
  value = "${aws_s3_bucket.terraform.bucket_domain_name}"
}

output "id" {
  value = "${aws_s3_bucket.terraform.id}"
}
