data "aws_iam_policy_document" "masters_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# reference: https://github.com/kubernetes/cloud-provider-aws#iam-policy
data "aws_iam_policy_document" "masters_cloud_provider_aws" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateRoute",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteRoute",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteVolume",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcs",
      "ec2:DetachVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyVolume",
      "ec2:RevokeSecurityGroupIngress",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
      "elasticloadbalancing:AttachLoadBalancerToSubnets",
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancerPolicies",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DetachLoadBalancerFromSubnets",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "iam:CreateServiceLinkedRole",
      "kms:DescribeKey",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeAccountAttributes",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "masters_kms_key" {
  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:PutParameter",
    ]

    resources = ["arn:aws:ssm:*:*:parameter/kubernetes/${local.name}/*"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
    ]

    resources = ["${aws_kms_key.kubernetes.arn}"]
  }
}

resource "aws_iam_role" "masters" {
  name               = "${local.name}-kubernetes-masters"
  assume_role_policy = "${data.aws_iam_policy_document.masters_assume_role.json}"
}

resource "aws_iam_role_policy" "masters_cloud_provider_aws" {
  name   = "${local.name}-cloud-provider-aws"
  role   = "${aws_iam_role.masters.name}"
  policy = "${data.aws_iam_policy_document.masters_cloud_provider_aws.json}"
}

resource "aws_iam_role_policy" "masters_kms_key" {
  name   = "${local.name}-kms-key"
  role   = "${aws_iam_role.masters.name}"
  policy = "${data.aws_iam_policy_document.masters_kms_key.json}"
}

resource "aws_iam_instance_profile" "masters" {
  name = "${local.name}-kubernetes-masters"
  role = "${aws_iam_role.masters.name}"
}

resource "aws_security_group" "masters" {
  name        = "${local.name}-kubernetes-masters"
  description = "Security group for PokedexTrackers Kubernetes Masters"
  vpc_id      = "${data.terraform_remote_state.network.vpc_id}"

  tags = "${merge(
    map("Name", "${local.name}-kubernetes-masters"),
    map("Project", "PokedexTracker"),
    map("kubernetes.io/cluster/${local.name}", "owned"),
  )}"
}

resource "aws_security_group_rule" "masters_self_ingress" {
  from_port         = 0
  protocol          = "all"
  security_group_id = "${aws_security_group.masters.id}"
  self              = true
  to_port           = 0
  type              = "ingress"
}

resource "aws_security_group_rule" "masters_all_egress" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  security_group_id = "${aws_security_group.masters.id}"
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "masters_cidr_ssh_ingress" {
  cidr_blocks       = ["${local.allowed_cidr_blocks}"]
  from_port         = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.masters.id}"
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "masters_vpc_api_ingress" {
  cidr_blocks       = ["${data.terraform_remote_state.network.cidr_block}"]
  from_port         = 6443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.masters.id}"
  to_port           = 6443
  type              = "ingress"
}

resource "aws_security_group_rule" "masters_cidr_api_ingress" {
  cidr_blocks       = ["${local.allowed_cidr_blocks}"]
  from_port         = 6443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.masters.id}"
  to_port           = 6443
  type              = "ingress"
}

resource "aws_security_group_rule" "masters_workers_api_ingress" {
  from_port                = 6443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.masters.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
  to_port                  = 6443
  type                     = "ingress"
}

resource "aws_eip" "master" {
  vpc = true
}

resource "aws_route53_record" "k8s_public" {
  zone_id = "${data.terraform_remote_state.dns.public_zone_id}"
  name    = "k8s"
  type    = "A"
  ttl     = 300
  records = ["${aws_eip.master.public_ip}"]
}

resource "aws_route53_record" "k8s_private" {
  zone_id = "${data.terraform_remote_state.dns.private_zone_id}"
  name    = "k8s"
  type    = "A"
  ttl     = 300
  records = ["${aws_instance.master.private_ip}"]
}

data "template_file" "masters_user_data" {
  template = "${file("masters-user-data.sh")}"

  vars {
    cluster_endpoint   = "${aws_route53_record.k8s_public.fqdn}"
    kubernetes_version = "${local.kubernetes_version}"
    name               = "${local.name}"
    pod_subnet         = "${local.pod_subnet}"
    region             = "${data.aws_region.current.name}"
    service_subnet     = "${local.service_subnet}"
  }
}

resource "aws_instance" "master" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.masters.id}"
  instance_type          = "t3.medium"
  key_name               = "${aws_key_pair.kubernetes.key_name}"
  subnet_id              = "${data.aws_subnet.public.id}"
  user_data_base64       = "${base64encode("${data.template_file.masters_user_data.rendered}")}"
  vpc_security_group_ids = ["${aws_security_group.masters.id}"]

  root_block_device {
    volume_type = "gp2"
    volume_size = 100
  }

  tags = "${merge(
    map("Name", "${local.name}-kubernetes-master"),
    map("Project", "PokedexTracker"),
    map("kubernetes.io/cluster/${local.name}", "owned"),
  )}"

  volume_tags = "${merge(
    map("Name", "${local.name}-kubernetes-master"),
    map("Project", "PokedexTracker"),
    map("kubernetes.io/cluster/${local.name}", "owned"),
  )}"
}

resource "aws_eip_association" "master" {
  instance_id   = "${aws_instance.master.id}"
  allocation_id = "${aws_eip.master.id}"
}
