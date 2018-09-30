# This was generated with the follow command and then slightly modified.

# kops create cluster \
#   --admin-access 136.24.25.248/32 \
#   --api-loadbalancer-type public \
#   --associate-public-ip \
#   --authorization RBAC \
#   --cloud aws \
#   --cloud-labels Project=PokedexTracker \
#   --dns public \
#   --encrypt-etcd-storage \
#   --image kope.io/k8s-1.9-debian-jessie-amd64-hvm-ebs-2018-03-11\
#   --master-public-name kube.pokedextracker.com \
#   --master-size t3.small \
#   --master-tenancy default \
#   --master-volume-size 16 \
#   --master-zones us-west-2a \
#   --name kube.pokedextracker.com \
#   --networking calico \
#   --node-count 2 \
#   --node-size t3.small \
#   --node-tenancy default \
#   --node-volume-size 32 \
#   --out . \
#   --ssh-access 136.24.25.248/32 \
#   --ssh-public-key ~/.ssh/pokedextracker-kubernetes.pub \
#   --state s3://kops-state.pokedextracker.com \
#   --subnets subnet-396b675f,subnet-28cce060,subnet-481be212 \
#   --target terraform \
#   --utility-subnets subnet-396b675f,subnet-28cce060,subnet-481be212 \
#   --vpc vpc-587db021 \
#   --zones us-west-2a,us-west-2b,us-west-2c

# Modifications include:
# - Removing the extraneous `provider` block
# - Adding the Project tag to everything

output "cluster_name" {
  value = "kube.pokedextracker.com"
}

output "master_security_group_ids" {
  value = ["${aws_security_group.masters-kube-pokedextracker-com.id}"]
}

output "masters_role_arn" {
  value = "${aws_iam_role.masters-kube-pokedextracker-com.arn}"
}

output "masters_role_name" {
  value = "${aws_iam_role.masters-kube-pokedextracker-com.name}"
}

output "node_security_group_ids" {
  value = ["${aws_security_group.nodes-kube-pokedextracker-com.id}"]
}

output "node_subnet_ids" {
  value = ["subnet-28cce060", "subnet-396b675f", "subnet-481be212"]
}

output "nodes_role_arn" {
  value = "${aws_iam_role.nodes-kube-pokedextracker-com.arn}"
}

output "nodes_role_name" {
  value = "${aws_iam_role.nodes-kube-pokedextracker-com.name}"
}

output "region" {
  value = "us-west-2"
}

output "subnet_ids" {
  value = ["subnet-28cce060", "subnet-396b675f", "subnet-481be212"]
}

output "vpc_id" {
  value = "vpc-587db021"
}

resource "aws_autoscaling_attachment" "master-us-west-2a-masters-kube-pokedextracker-com" {
  elb                    = "${aws_elb.api-kube-pokedextracker-com.id}"
  autoscaling_group_name = "${aws_autoscaling_group.master-us-west-2a-masters-kube-pokedextracker-com.id}"
}

resource "aws_autoscaling_group" "master-us-west-2a-masters-kube-pokedextracker-com" {
  name                 = "master-us-west-2a.masters.kube.pokedextracker.com"
  launch_configuration = "${aws_launch_configuration.master-us-west-2a-masters-kube-pokedextracker-com.id}"
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = ["subnet-396b675f"]

  tag = {
    key                 = "KubernetesCluster"
    value               = "kube.pokedextracker.com"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Name"
    value               = "master-us-west-2a.masters.kube.pokedextracker.com"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Project"
    value               = "PokedexTracker"
    propagate_at_launch = true
  }

  tag = {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"
    value               = "master-us-west-2a"
    propagate_at_launch = true
  }

  tag = {
    key                 = "k8s.io/role/master"
    value               = "1"
    propagate_at_launch = true
  }

  metrics_granularity = "1Minute"
  enabled_metrics     = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupMaxSize", "GroupMinSize", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
}

resource "aws_autoscaling_group" "nodes-kube-pokedextracker-com" {
  name                 = "nodes.kube.pokedextracker.com"
  launch_configuration = "${aws_launch_configuration.nodes-kube-pokedextracker-com.id}"
  max_size             = 3
  min_size             = 3
  vpc_zone_identifier  = ["subnet-396b675f", "subnet-28cce060", "subnet-481be212"]

  tag = {
    key                 = "KubernetesCluster"
    value               = "kube.pokedextracker.com"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Name"
    value               = "nodes.kube.pokedextracker.com"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Project"
    value               = "PokedexTracker"
    propagate_at_launch = true
  }

  tag = {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/kops.k8s.io/instancegroup"
    value               = "nodes"
    propagate_at_launch = true
  }

  tag = {
    key                 = "k8s.io/role/node"
    value               = "1"
    propagate_at_launch = true
  }

  metrics_granularity = "1Minute"
  enabled_metrics     = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupMaxSize", "GroupMinSize", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
}

resource "aws_ebs_volume" "a-etcd-events-kube-pokedextracker-com" {
  availability_zone = "us-west-2a"
  size              = 20
  type              = "gp2"
  encrypted         = true

  tags = {
    KubernetesCluster                               = "kube.pokedextracker.com"
    Name                                            = "a.etcd-events.kube.pokedextracker.com"
    Project                                         = "PokedexTracker"
    "k8s.io/etcd/events"                            = "a/a"
    "k8s.io/role/master"                            = "1"
    "kubernetes.io/cluster/kube.pokedextracker.com" = "owned"
  }
}

resource "aws_ebs_volume" "a-etcd-main-kube-pokedextracker-com" {
  availability_zone = "us-west-2a"
  size              = 20
  type              = "gp2"
  encrypted         = true

  tags = {
    KubernetesCluster                               = "kube.pokedextracker.com"
    Name                                            = "a.etcd-main.kube.pokedextracker.com"
    Project                                         = "PokedexTracker"
    "k8s.io/etcd/main"                              = "a/a"
    "k8s.io/role/master"                            = "1"
    "kubernetes.io/cluster/kube.pokedextracker.com" = "owned"
  }
}

resource "aws_elb" "api-kube-pokedextracker-com" {
  name = "api-kube-pokedextracker-c-tuktkt"

  listener = {
    instance_port     = 443
    instance_protocol = "TCP"
    lb_port           = 443
    lb_protocol       = "TCP"
  }

  security_groups = ["${aws_security_group.api-elb-kube-pokedextracker-com.id}"]
  subnets         = ["subnet-28cce060", "subnet-396b675f", "subnet-481be212"]

  health_check = {
    target              = "SSL:443"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    timeout             = 5
  }

  idle_timeout = 300

  tags = {
    KubernetesCluster = "kube.pokedextracker.com"
    Name              = "api.kube.pokedextracker.com"
    Project           = "PokedexTracker"
  }
}

resource "aws_iam_instance_profile" "masters-kube-pokedextracker-com" {
  name = "masters.kube.pokedextracker.com"
  role = "${aws_iam_role.masters-kube-pokedextracker-com.name}"
}

resource "aws_iam_instance_profile" "nodes-kube-pokedextracker-com" {
  name = "nodes.kube.pokedextracker.com"
  role = "${aws_iam_role.nodes-kube-pokedextracker-com.name}"
}

resource "aws_iam_role" "masters-kube-pokedextracker-com" {
  name               = "masters.kube.pokedextracker.com"
  assume_role_policy = "${file("${path.module}/data/aws_iam_role_masters.kube.pokedextracker.com_policy")}"
}

resource "aws_iam_role" "nodes-kube-pokedextracker-com" {
  name               = "nodes.kube.pokedextracker.com"
  assume_role_policy = "${file("${path.module}/data/aws_iam_role_nodes.kube.pokedextracker.com_policy")}"
}

resource "aws_iam_role_policy" "masters-kube-pokedextracker-com" {
  name   = "masters.kube.pokedextracker.com"
  role   = "${aws_iam_role.masters-kube-pokedextracker-com.name}"
  policy = "${file("${path.module}/data/aws_iam_role_policy_masters.kube.pokedextracker.com_policy")}"
}

resource "aws_iam_role_policy" "nodes-kube-pokedextracker-com" {
  name   = "nodes.kube.pokedextracker.com"
  role   = "${aws_iam_role.nodes-kube-pokedextracker-com.name}"
  policy = "${file("${path.module}/data/aws_iam_role_policy_nodes.kube.pokedextracker.com_policy")}"
}

resource "aws_key_pair" "kubernetes-kube-pokedextracker-com-6aa30f40dd576a5acb4943581ef88bca" {
  key_name   = "kubernetes.kube.pokedextracker.com-6a:a3:0f:40:dd:57:6a:5a:cb:49:43:58:1e:f8:8b:ca"
  public_key = "${file("${path.module}/data/aws_key_pair_kubernetes.kube.pokedextracker.com-6aa30f40dd576a5acb4943581ef88bca_public_key")}"
}

resource "aws_launch_configuration" "master-us-west-2a-masters-kube-pokedextracker-com" {
  name_prefix                 = "master-us-west-2a.masters.kube.pokedextracker.com-"
  image_id                    = "ami-4bfe6f33"
  instance_type               = "t2.micro"
  key_name                    = "${aws_key_pair.kubernetes-kube-pokedextracker-com-6aa30f40dd576a5acb4943581ef88bca.id}"
  iam_instance_profile        = "${aws_iam_instance_profile.masters-kube-pokedextracker-com.id}"
  security_groups             = ["${aws_security_group.masters-kube-pokedextracker-com.id}"]
  associate_public_ip_address = true
  user_data                   = "${file("${path.module}/data/aws_launch_configuration_master-us-west-2a.masters.kube.pokedextracker.com_user_data")}"

  root_block_device = {
    volume_type           = "gp2"
    volume_size           = 16
    delete_on_termination = true
  }

  lifecycle = {
    create_before_destroy = true
  }

  placement_tenancy = "default"
  enable_monitoring = false
}

resource "aws_launch_configuration" "nodes-kube-pokedextracker-com" {
  name_prefix                 = "nodes.kube.pokedextracker.com-"
  image_id                    = "ami-4bfe6f33"
  instance_type               = "t2.micro"
  key_name                    = "${aws_key_pair.kubernetes-kube-pokedextracker-com-6aa30f40dd576a5acb4943581ef88bca.id}"
  iam_instance_profile        = "${aws_iam_instance_profile.nodes-kube-pokedextracker-com.id}"
  security_groups             = ["${aws_security_group.nodes-kube-pokedextracker-com.id}"]
  associate_public_ip_address = true
  user_data                   = "${file("${path.module}/data/aws_launch_configuration_nodes.kube.pokedextracker.com_user_data")}"

  root_block_device = {
    volume_type           = "gp2"
    volume_size           = 32
    delete_on_termination = true
  }

  lifecycle = {
    create_before_destroy = true
  }

  placement_tenancy = "default"
  enable_monitoring = false
}

resource "aws_route53_record" "kube-pokedextracker-com" {
  name = "kube.pokedextracker.com"
  type = "A"

  alias = {
    name                   = "${aws_elb.api-kube-pokedextracker-com.dns_name}"
    zone_id                = "${aws_elb.api-kube-pokedextracker-com.zone_id}"
    evaluate_target_health = false
  }

  zone_id = "/hostedzone/Z1X7S3HZAHV4ZZ"
}

resource "aws_security_group" "api-elb-kube-pokedextracker-com" {
  name        = "api-elb.kube.pokedextracker.com"
  vpc_id      = "vpc-587db021"
  description = "Security group for api ELB"

  tags = {
    KubernetesCluster                               = "kube.pokedextracker.com"
    Name                                            = "api-elb.kube.pokedextracker.com"
    Project                                         = "PokedexTracker"
    "kubernetes.io/cluster/kube.pokedextracker.com" = "owned"
  }
}

resource "aws_security_group" "masters-kube-pokedextracker-com" {
  name        = "masters.kube.pokedextracker.com"
  vpc_id      = "vpc-587db021"
  description = "Security group for masters"

  tags = {
    KubernetesCluster                               = "kube.pokedextracker.com"
    Name                                            = "masters.kube.pokedextracker.com"
    Project                                         = "PokedexTracker"
    "kubernetes.io/cluster/kube.pokedextracker.com" = "owned"
  }
}

resource "aws_security_group" "nodes-kube-pokedextracker-com" {
  name        = "nodes.kube.pokedextracker.com"
  vpc_id      = "vpc-587db021"
  description = "Security group for nodes"

  tags = {
    KubernetesCluster                               = "kube.pokedextracker.com"
    Name                                            = "nodes.kube.pokedextracker.com"
    Project                                         = "PokedexTracker"
    "kubernetes.io/cluster/kube.pokedextracker.com" = "owned"
  }
}

resource "aws_security_group_rule" "all-master-to-master" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}

resource "aws_security_group_rule" "all-master-to-node" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}

resource "aws_security_group_rule" "all-node-to-node" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}

resource "aws_security_group_rule" "api-elb-egress" {
  type              = "egress"
  security_group_id = "${aws_security_group.api-elb-kube-pokedextracker-com.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https-api-elb-136-24-25-248--32" {
  type              = "ingress"
  security_group_id = "${aws_security_group.api-elb-kube-pokedextracker-com.id}"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["136.24.25.248/32"]
}

resource "aws_security_group_rule" "https-elb-to-master" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.api-elb-kube-pokedextracker-com.id}"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "master-egress" {
  type              = "egress"
  security_group_id = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node-egress" {
  type              = "egress"
  security_group_id = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node-to-master-tcp-1-2379" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  from_port                = 1
  to_port                  = 2379
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "node-to-master-tcp-2382-4000" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  from_port                = 2382
  to_port                  = 4000
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "node-to-master-tcp-4003-65535" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  from_port                = 4003
  to_port                  = 65535
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "node-to-master-udp-1-65535" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  from_port                = 1
  to_port                  = 65535
  protocol                 = "udp"
}

resource "aws_security_group_rule" "ssh-external-to-master-136-24-25-248--32" {
  type              = "ingress"
  security_group_id = "${aws_security_group.masters-kube-pokedextracker-com.id}"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["136.24.25.248/32"]
}

resource "aws_security_group_rule" "ssh-external-to-node-136-24-25-248--32" {
  type              = "ingress"
  security_group_id = "${aws_security_group.nodes-kube-pokedextracker-com.id}"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["136.24.25.248/32"]
}

terraform = {
  required_version = ">= 0.9.3"
}
