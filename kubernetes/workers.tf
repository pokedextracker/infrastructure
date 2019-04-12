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
    resources = ["arn:aws:ssm:*:*:parameter/kubernetes/${local.name}/*"]
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
  name               = "${local.name}-kubernetes-workers"
  assume_role_policy = "${data.aws_iam_policy_document.workers_assume_role.json}"
}

resource "aws_iam_role_policy" "workers_cloud_provider_aws" {
  name   = "${local.name}-cloud-provider-aws"
  role   = "${aws_iam_role.workers.name}"
  policy = "${data.aws_iam_policy_document.workers_cloud_provider_aws.json}"
}

resource "aws_iam_role_policy" "workers_kms_key" {
  name   = "${local.name}-kms-key"
  role   = "${aws_iam_role.workers.name}"
  policy = "${data.aws_iam_policy_document.workers_kms_key.json}"
}

resource "aws_iam_role_policy" "workers_kube2iam" {
  name   = "${local.name}-kube2iam"
  role   = "${aws_iam_role.workers.name}"
  policy = "${data.aws_iam_policy_document.workers_kube2iam.json}"
}

resource "aws_iam_instance_profile" "workers" {
  name = "${local.name}-kubernetes-workers"
  role = "${aws_iam_role.workers.name}"
}

##############################
#  Security Group Resources  #
##############################

resource "aws_security_group" "workers" {
  name        = "${local.name}-kubernetes-workers"
  description = "Security group for PokedexTrackers Kubernetes Workers"
  vpc_id      = "${data.terraform_remote_state.network.vpc_id}"

  tags = "${merge(
    map("Name", "${local.name}-kubernetes-workers"),
    map("Project", "PokedexTracker"),
    map("kubernetes.io/cluster/${local.name}", "owned"),
  )}"
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
  cidr_blocks       = ["${local.allowed_cidr_blocks}"]
  from_port         = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.workers.id}"
  to_port           = 22
  type              = "ingress"
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
  cidr_blocks       = ["${data.terraform_remote_state.network.cidr_block}"]
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
  template = "${file("workers-user-data.sh")}"

  vars {
    cluster_endpoint_internal = "${local.cluster_endpoint_internal}"
    kubernetes_version        = "${local.kubernetes_version}"
    name                      = "${local.name}"
    pod_subnet                = "${local.pod_subnet}"
    region                    = "${data.aws_region.current.name}"
    service_subnet            = "${local.service_subnet}"
  }
}

resource "aws_launch_template" "workers" {
  ebs_optimized                        = true
  image_id                             = "${data.aws_ami.ubuntu.id}"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.medium"
  key_name                             = "${aws_key_pair.kubernetes.key_name}"
  name_prefix                          = "${local.name}-kubernetes-workers-"
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

    tags = "${merge(
      map("Name", "${local.name}-kubernetes-worker"),
      map("Role", "worker"),
      map("Project", "PokedexTracker"),
      map("kubernetes.io/cluster/${local.name}", "owned"),
    )}"
  }

  tag_specifications {
    resource_type = "volume"

    tags = "${merge(
      map("Name", "${local.name}-kubernetes-worker"),
      map("Role", "worker"),
      map("Project", "PokedexTracker"),
      map("kubernetes.io/cluster/${local.name}", "owned"),
    )}"
  }

  tags = "${merge(
    map("Name", "${local.name}-kubernetes-worker"),
    map("Role", "worker"),
    map("Project", "PokedexTracker"),
    map("kubernetes.io/cluster/${local.name}", "owned"),
  )}"
}

resource "aws_autoscaling_group" "workers" {
  desired_capacity     = "${local.worker_count}"
  max_size             = "${local.worker_count * 2}"
  min_size             = 0
  name                 = "${local.name}-kubernetes-workers"
  termination_policies = ["OldestLaunchTemplate", "OldestInstance", "ClosestToNextInstanceHour", "Default"]
  vpc_zone_identifier  = ["${data.terraform_remote_state.network.public_subnets}"]

  launch_template {
    id      = "${aws_launch_template.workers.id}"
    version = "$$Latest"
  }
}
