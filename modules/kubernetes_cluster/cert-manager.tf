data "aws_iam_policy_document" "cert_manager_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_iam_role.workers.arn}"]
    }
  }
}

# https://docs.cert-manager.io/en/latest/tasks/acme/configuring-dns01/route53.html
data "aws_iam_policy_document" "cert_manager" {
  statement {
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"]
  }

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.dns_zone_id}"]
  }

  statement {
    actions   = ["route53:GetChange"]
    resources = ["arn:aws:route53:::change/*"]
  }
}

resource "aws_iam_role" "cert_manager" {
  name               = "kubernetes-${var.name}-${random_id.hash.hex}-cert-manager"
  path               = "${local.kube2iam_iam_path}"
  assume_role_policy = "${data.aws_iam_policy_document.cert_manager_assume_role.json}"
}

resource "aws_iam_role_policy" "cert_manager" {
  name   = "route53-permissions"
  role   = "${aws_iam_role.cert_manager.id}"
  policy = "${data.aws_iam_policy_document.cert_manager.json}"
}
