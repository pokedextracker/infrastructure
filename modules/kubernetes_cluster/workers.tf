###################
#  IAM Resources  #
###################

data "aws_iam_policy_document" "workers_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# reference: https://github.com/kubernetes/cloud-provider-aws#iam-policy
data "aws_iam_policy_document" "workers_cloud_provider_aws" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "workers_kms_key" {
  statement {
    actions   = ["ssm:GetParameters"]
    resources = ["arn:aws:ssm:*:*:parameter/kubernetes/${var.name}-${random_id.hash.hex}/*"]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = ["${aws_kms_key.kubernetes.arn}"]
  }
}

# https://github.com/jtblin/kube2iam#iam-roles
data "aws_iam_policy_document" "workers_kube2iam" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role${local.kube2iam_iam_path}*"]
  }
}

resource "aws_iam_role" "workers" {
  name               = "${var.name}-${random_id.hash.hex}-kubernetes-workers"
  assume_role_policy = "${data.aws_iam_policy_document.workers_assume_role.json}"
}

resource "aws_iam_role_policy" "workers_cloud_provider_aws" {
  name   = "cloud-provider-aws"
  role   = "${aws_iam_role.workers.name}"
  policy = "${data.aws_iam_policy_document.workers_cloud_provider_aws.json}"
}

resource "aws_iam_role_policy" "workers_kms_key" {
  name   = "kms-key"
  role   = "${aws_iam_role.workers.name}"
  policy = "${data.aws_iam_policy_document.workers_kms_key.json}"
}

resource "aws_iam_role_policy" "workers_kube2iam" {
  name   = "kube2iam"
  role   = "${aws_iam_role.workers.name}"
  policy = "${data.aws_iam_policy_document.workers_kube2iam.json}"
}

resource "aws_iam_instance_profile" "workers" {
  name = "${var.name}-${random_id.hash.hex}-kubernetes-workers"
  role = "${aws_iam_role.workers.name}"
}

##############################
#  Security Group Resources  #
##############################

resource "aws_security_group" "workers" {
  name        = "${var.name}-${random_id.hash.hex}-kubernetes-workers"
  description = "Security group for PokedexTrackers Kubernetes Workers"
  vpc_id      = "${data.aws_vpc.main.id}"

  tags = {
    Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-workers",
    Project                             = "PokedexTracker",
    "kubernetes.io/cluster/${var.name}" = "owned",
  }
}

resource "aws_security_group_rule" "workers_self_ingress" {
  from_port         = 0
  protocol          = "all"
  security_group_id = "${aws_security_group.workers.id}"
  self              = true
  to_port           = 0
  type              = "ingress"
}

resource "aws_security_group_rule" "workers_all_egress" {
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  protocol          = "all"
  security_group_id = "${aws_security_group.workers.id}"
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "workers_cidr_ssh_ingress" {
  cidr_blocks       = var.allowed_cidr_blocks
  from_port         = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.workers.id}"
  to_port           = 22
  type              = "ingress"
}

resource "aws_security_group_rule" "workers_masters_vxlan_ingress" {
  from_port                = 8472
  protocol                 = "udp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.masters.id}"
  to_port                  = 8472
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_masters_kubelet_ingress" {
  from_port                = 10250
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.workers.id}"
  source_security_group_id = "${aws_security_group.masters.id}"
  to_port                  = 10250
  type                     = "ingress"
}

resource "aws_security_group_rule" "workers_vpc_nodeport_ingress" {
  cidr_blocks       = ["${data.aws_vpc.main.cidr_block}"]
  from_port         = 30000
  protocol          = "tcp"
  security_group_id = "${aws_security_group.workers.id}"
  to_port           = 32767
  type              = "ingress"
}

###################
#  ASG Resources  #
###################

data "template_file" "workers_user_data" {
  template = "${file("${path.module}/workers-user-data.sh")}"

  vars = {
    cluster_endpoint_internal = "${local.cluster_endpoint_internal}"
    hash                      = "${random_id.hash.hex}"
    kubernetes_version        = "${var.kubernetes_version}"
    name                      = "${var.name}"
    pod_subnet                = "${var.pod_subnet}"
    region                    = "${data.aws_region.current.name}"
    service_subnet            = "${var.service_subnet}"
  }
}

resource "aws_launch_template" "workers" {
  ebs_optimized                        = true
  image_id                             = "${var.ami_id}"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.medium"
  key_name                             = "${var.key_name}"
  name_prefix                          = "${var.name}-${random_id.hash.hex}-kubernetes-workers-"
  user_data                            = "${base64encode("${data.template_file.workers_user_data.rendered}")}"
  vpc_security_group_ids               = ["${aws_security_group.workers.id}"]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 50
    }
  }

  iam_instance_profile {
    arn = "${aws_iam_instance_profile.workers.arn}"
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-worker",
      Role                                = "worker",
      Project                             = "PokedexTracker",
      "kubernetes.io/cluster/${var.name}" = "owned",
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-worker",
      Role                                = "worker",
      Project                             = "PokedexTracker",
      "kubernetes.io/cluster/${var.name}" = "owned",
    }
  }

  tags = {
    Name                                = "${var.name}-${random_id.hash.hex}-kubernetes-worker",
    Role                                = "worker",
    Project                             = "PokedexTracker",
    "kubernetes.io/cluster/${var.name}" = "owned",
  }
}

resource "aws_autoscaling_group" "workers" {
  desired_capacity     = "${var.worker_count}"
  max_size             = "${var.worker_count * 2}"
  min_size             = 0
  name                 = "${var.name}-${random_id.hash.hex}-kubernetes-workers"
  termination_policies = ["OldestLaunchTemplate", "OldestInstance", "ClosestToNextInstanceHour", "Default"]
  vpc_zone_identifier  = ["${var.subnet_id}"]

  launch_template {
    id      = "${aws_launch_template.workers.id}"
    version = "$Latest"
  }
}
