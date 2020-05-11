data "aws_region" "current" {}

data "aws_subnet" "main" {
  id = "${var.subnet_id}"
}

data "aws_vpc" "main" {
  id = "${data.aws_subnet.main.vpc_id}"
}

resource "random_id" "hash" {
  byte_length = 3
}

locals {
  cluster_endpoint          = "${random_id.hash.hex}.k8s.pokedextracker.com"
  cluster_endpoint_internal = "${random_id.hash.hex}.k8s.internal.pokedextracker.com"
  kube2iam_iam_path         = "/kubernetes/${var.name}/"
}

resource "aws_kms_key" "kubernetes" {
  description             = "${var.name}-${random_id.hash.hex}-kubernetes"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  is_enabled              = true

  tags {
    Name    = "${var.name}-${random_id.hash.hex}-kubernetes"
    Project = "PokedexTracker"
    Module  = "kubernetes_cluster"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_kms_alias" "kubernetes" {
  name          = "alias/${var.name}-${random_id.hash.hex}-kubernetes"
  target_key_id = "${aws_kms_key.kubernetes.id}"
}
