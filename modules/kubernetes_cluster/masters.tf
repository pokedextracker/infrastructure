###################
#  IAM Resources  #
###################

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

    resources = ["arn:aws:ssm:*:*:parameter/kubernetes/${var.name}-${random_id.hash.hex}/*"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
    ]

    resources = ["${aws_kms_key.kubernetes.arn}"]
  }
}

data "aws_iam_policy_document" "masters_route53" {
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${var.dns_zone_id}"]
  }
}

resource "aws_iam_role" "masters" {
  name               = "${var.name}-${random_id.hash.hex}-kubernetes-masters"
  assume_role_policy = "${data.aws_iam_policy_document.masters_assume_role.json}"
}

resource "aws_iam_role_policy" "masters_cloud_provider_aws" {
  name   = "cloud-provider-aws"
  role   = "${aws_iam_role.masters.name}"
  policy = "${data.aws_iam_policy_document.masters_cloud_provider_aws.json}"
}

resource "aws_iam_role_policy" "masters_kms_key" {
  name   = "kms-key"
  role   = "${aws_iam_role.masters.name}"
  policy = "${data.aws_iam_policy_document.masters_kms_key.json}"
}

resource "aws_iam_role_policy" "masters_route53" {
  name   = "route53"
  role   = "${aws_iam_role.masters.name}"
  policy = "${data.aws_iam_policy_document.masters_route53.json}"
}

resource "aws_iam_instance_profile" "masters" {
  name = "${var.name}-${random_id.hash.hex}-kubernetes-masters"
  role = "${aws_iam_role.masters.name}"
}

##############################
#  Security Group Resources  #
##############################

resource "aws_security_group" "masters" {
  name        = "${var.name}-${random_id.hash.hex}-kubernetes-masters"
  description = "Security group for ${var.name}-${random_id.hash.hex} Kubernetes Masters"
  vpc_id      = "${data.aws_vpc.main.id}"

  tags = {
    Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-masters",
    Project                             = "PokedexTracker",
    Module                              = "kubernetes_cluster",
    "kubernetes.io/cluster/${var.name}" = "owned",
  }
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
  cidr_blocks       = var.allowed_cidr_blocks
  from_port         = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.masters.id}"
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "masters_vpc_api_ingress" {
  cidr_blocks       = ["${data.aws_vpc.main.cidr_block}"]
  from_port         = 6443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.masters.id}"
  to_port           = 6443
  type              = "ingress"
}

resource "aws_security_group_rule" "masters_cidr_api_ingress" {
  cidr_blocks       = var.allowed_cidr_blocks
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

resource "aws_security_group_rule" "masters_workers_vxlan_ingress" {
  from_port                = 8472
  protocol                 = "udp"
  security_group_id        = "${aws_security_group.masters.id}"
  source_security_group_id = "${aws_security_group.workers.id}"
  to_port                  = 8472
  type                     = "ingress"
}

###################
#  EFS Resources  #
###################

resource "aws_efs_file_system" "mnt" {
  encrypted = true

  tags = {
    Name    = "${var.name}-${random_id.hash.hex}-kubernetes",
    Project = "PokedexTracker",
    Module  = "kubernetes_cluster",
  }
}

resource "aws_efs_mount_target" "mnt" {
  file_system_id  = "${aws_efs_file_system.mnt.id}"
  subnet_id       = "${var.subnet_id}"
  security_groups = ["${aws_security_group.masters.id}"]
}

###################
#  ASG Resources  #
###################

data "template_file" "masters_user_data" {
  template = "${file("${path.module}/masters-user-data.sh")}"

  vars = {
    cluster_endpoint          = "${local.cluster_endpoint}"
    cluster_endpoint_internal = "${local.cluster_endpoint_internal}"
    efs_dns_name              = "${aws_efs_file_system.mnt.dns_name}"
    hash                      = "${random_id.hash.hex}"
    hosted_zone_id            = "${var.dns_zone_id}"
    kubernetes_version        = "${var.kubernetes_version}"
    name                      = "${var.name}"
    pod_subnet                = "${var.pod_subnet}"
    region                    = "${data.aws_region.current.name}"
    service_subnet            = "${var.service_subnet}"
  }
}

resource "aws_launch_template" "masters" {
  ebs_optimized                        = true
  image_id                             = "${var.ami_id}"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.medium"
  key_name                             = "${var.key_name}"
  name_prefix                          = "${var.name}-${random_id.hash.hex}-kubernetes-masters-"
  user_data                            = "${base64encode("${data.template_file.masters_user_data.rendered}")}"
  vpc_security_group_ids               = ["${aws_security_group.masters.id}"]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 50
    }
  }

  iam_instance_profile {
    arn = "${aws_iam_instance_profile.masters.arn}"
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-master",
      Role                                = "master",
      Project                             = "PokedexTracker",
      "kubernetes.io/cluster/${var.name}" = "owned",
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-master",
      Role                                = "master",
      Project                             = "PokedexTracker",
      "kubernetes.io/cluster/${var.name}" = "owned",
    }
  }

  tags = {
    Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-master",
    Role                                = "master",
    Project                             = "PokedexTracker",
    "kubernetes.io/cluster/${var.name}" = "owned",
  }

  depends_on = [aws_efs_mount_target.mnt]
}

resource "aws_autoscaling_group" "masters" {
  desired_capacity     = "${var.master_count}"
  max_size             = "${var.master_count * 2}"
  min_size             = 0
  name                 = "${var.name}-${random_id.hash.hex}-kubernetes-masters"
  termination_policies = ["OldestLaunchTemplate", "OldestInstance", "ClosestToNextInstanceHour", "Default"]
  vpc_zone_identifier  = ["${var.subnet_id}"]

  launch_template {
    id      = "${aws_launch_template.masters.id}"
    version = "$Latest"
  }
}
