locals = {
  cluster_name                 = "k8s.pokedextracker.com"
  master_autoscaling_group_ids = ["${aws_autoscaling_group.master-us-west-2a-masters-k8s-pokedextracker-com.id}"]
  master_security_group_ids    = ["${aws_security_group.masters-k8s-pokedextracker-com.id}"]
  masters_role_arn             = "${aws_iam_role.masters-k8s-pokedextracker-com.arn}"
  masters_role_name            = "${aws_iam_role.masters-k8s-pokedextracker-com.name}"
  node_autoscaling_group_ids   = ["${aws_autoscaling_group.nodes-k8s-pokedextracker-com.id}"]
  node_security_group_ids      = ["${aws_security_group.nodes-k8s-pokedextracker-com.id}"]
  node_subnet_ids              = ["subnet-28cce060", "subnet-396b675f", "subnet-481be212"]
  nodes_role_arn               = "${aws_iam_role.nodes-k8s-pokedextracker-com.arn}"
  nodes_role_name              = "${aws_iam_role.nodes-k8s-pokedextracker-com.name}"
  region                       = "us-west-2"
  subnet_ids                   = ["subnet-28cce060", "subnet-396b675f", "subnet-481be212"]
  subnet_us-west-2a_id         = "subnet-396b675f"
  subnet_us-west-2b_id         = "subnet-28cce060"
  subnet_us-west-2c_id         = "subnet-481be212"
  vpc_id                       = "vpc-587db021"
}

output "cluster_name" {
  value = "k8s.pokedextracker.com"
}

output "master_autoscaling_group_ids" {
  value = ["${aws_autoscaling_group.master-us-west-2a-masters-k8s-pokedextracker-com.id}"]
}

output "master_security_group_ids" {
  value = ["${aws_security_group.masters-k8s-pokedextracker-com.id}"]
}

output "masters_role_arn" {
  value = "${aws_iam_role.masters-k8s-pokedextracker-com.arn}"
}

output "masters_role_name" {
  value = "${aws_iam_role.masters-k8s-pokedextracker-com.name}"
}

output "node_autoscaling_group_ids" {
  value = ["${aws_autoscaling_group.nodes-k8s-pokedextracker-com.id}"]
}

output "node_security_group_ids" {
  value = ["${aws_security_group.nodes-k8s-pokedextracker-com.id}"]
}

output "node_subnet_ids" {
  value = ["subnet-28cce060", "subnet-396b675f", "subnet-481be212"]
}

output "nodes_role_arn" {
  value = "${aws_iam_role.nodes-k8s-pokedextracker-com.arn}"
}

output "nodes_role_name" {
  value = "${aws_iam_role.nodes-k8s-pokedextracker-com.name}"
}

output "region" {
  value = "us-west-2"
}

output "subnet_ids" {
  value = ["subnet-28cce060", "subnet-396b675f", "subnet-481be212"]
}

output "subnet_us-west-2a_id" {
  value = "subnet-396b675f"
}

output "subnet_us-west-2b_id" {
  value = "subnet-28cce060"
}

output "subnet_us-west-2c_id" {
  value = "subnet-481be212"
}

output "vpc_id" {
  value = "vpc-587db021"
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_autoscaling_attachment" "master-us-west-2a-masters-k8s-pokedextracker-com" {
  elb                    = "${aws_elb.api-k8s-pokedextracker-com.id}"
  autoscaling_group_name = "${aws_autoscaling_group.master-us-west-2a-masters-k8s-pokedextracker-com.id}"
}

resource "aws_autoscaling_group" "master-us-west-2a-masters-k8s-pokedextracker-com" {
  name                 = "master-us-west-2a.masters.k8s.pokedextracker.com"
  launch_configuration = "${aws_launch_configuration.master-us-west-2a-masters-k8s-pokedextracker-com.id}"
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = ["subnet-396b675f"]

  tag = {
    key                 = "KubernetesCluster"
    value               = "k8s.pokedextracker.com"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Name"
    value               = "master-us-west-2a.masters.k8s.pokedextracker.com"
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

resource "aws_autoscaling_group" "nodes-k8s-pokedextracker-com" {
  name                 = "nodes.k8s.pokedextracker.com"
  launch_configuration = "${aws_launch_configuration.nodes-k8s-pokedextracker-com.id}"
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = ["subnet-396b675f", "subnet-28cce060", "subnet-481be212"]

  tag = {
    key                 = "KubernetesCluster"
    value               = "k8s.pokedextracker.com"
    propagate_at_launch = true
  }

  tag = {
    key                 = "Name"
    value               = "nodes.k8s.pokedextracker.com"
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

resource "aws_ebs_volume" "a-etcd-events-k8s-pokedextracker-com" {
  availability_zone = "us-west-2a"
  size              = 20
  type              = "gp2"
  encrypted         = true

  tags = {
    KubernetesCluster                              = "k8s.pokedextracker.com"
    Name                                           = "a.etcd-events.k8s.pokedextracker.com"
    Project                                        = "PokedexTracker"
    "k8s.io/etcd/events"                           = "a/a"
    "k8s.io/role/master"                           = "1"
    "kubernetes.io/cluster/k8s.pokedextracker.com" = "owned"
  }
}

resource "aws_ebs_volume" "a-etcd-main-k8s-pokedextracker-com" {
  availability_zone = "us-west-2a"
  size              = 20
  type              = "gp2"
  encrypted         = true

  tags = {
    KubernetesCluster                              = "k8s.pokedextracker.com"
    Name                                           = "a.etcd-main.k8s.pokedextracker.com"
    Project                                        = "PokedexTracker"
    "k8s.io/etcd/main"                             = "a/a"
    "k8s.io/role/master"                           = "1"
    "kubernetes.io/cluster/k8s.pokedextracker.com" = "owned"
  }
}

resource "aws_elb" "api-k8s-pokedextracker-com" {
  name = "api-k8s-pokedextracker-co-1gufra"

  listener = {
    instance_port     = 443
    instance_protocol = "TCP"
    lb_port           = 443
    lb_protocol       = "TCP"
  }

  security_groups = ["${aws_security_group.api-elb-k8s-pokedextracker-com.id}"]
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
    KubernetesCluster = "k8s.pokedextracker.com"
    Name              = "api.k8s.pokedextracker.com"
  }
}

resource "aws_iam_instance_profile" "masters-k8s-pokedextracker-com" {
  name = "masters.k8s.pokedextracker.com"
  role = "${aws_iam_role.masters-k8s-pokedextracker-com.name}"
}

resource "aws_iam_instance_profile" "nodes-k8s-pokedextracker-com" {
  name = "nodes.k8s.pokedextracker.com"
  role = "${aws_iam_role.nodes-k8s-pokedextracker-com.name}"
}

resource "aws_iam_role" "masters-k8s-pokedextracker-com" {
  name               = "masters.k8s.pokedextracker.com"
  assume_role_policy = "${file("${path.module}/data/aws_iam_role_masters.k8s.pokedextracker.com_policy")}"
}

resource "aws_iam_role" "nodes-k8s-pokedextracker-com" {
  name               = "nodes.k8s.pokedextracker.com"
  assume_role_policy = "${file("${path.module}/data/aws_iam_role_nodes.k8s.pokedextracker.com_policy")}"
}

resource "aws_iam_role_policy" "masters-k8s-pokedextracker-com" {
  name   = "masters.k8s.pokedextracker.com"
  role   = "${aws_iam_role.masters-k8s-pokedextracker-com.name}"
  policy = "${file("${path.module}/data/aws_iam_role_policy_masters.k8s.pokedextracker.com_policy")}"
}

resource "aws_iam_role_policy" "nodes-k8s-pokedextracker-com" {
  name   = "nodes.k8s.pokedextracker.com"
  role   = "${aws_iam_role.nodes-k8s-pokedextracker-com.name}"
  policy = "${file("${path.module}/data/aws_iam_role_policy_nodes.k8s.pokedextracker.com_policy")}"
}

resource "aws_key_pair" "kubernetes-k8s-pokedextracker-com-6aa30f40dd576a5acb4943581ef88bca" {
  key_name   = "kubernetes.k8s.pokedextracker.com-6a:a3:0f:40:dd:57:6a:5a:cb:49:43:58:1e:f8:8b:ca"
  public_key = "${file("${path.module}/data/aws_key_pair_kubernetes.k8s.pokedextracker.com-6aa30f40dd576a5acb4943581ef88bca_public_key")}"
}

resource "aws_launch_configuration" "master-us-west-2a-masters-k8s-pokedextracker-com" {
  name_prefix                 = "master-us-west-2a.masters.k8s.pokedextracker.com-"
  image_id                    = "ami-a1e199d9"
  instance_type               = "t2.medium"
  key_name                    = "${aws_key_pair.kubernetes-k8s-pokedextracker-com-6aa30f40dd576a5acb4943581ef88bca.id}"
  iam_instance_profile        = "${aws_iam_instance_profile.masters-k8s-pokedextracker-com.id}"
  security_groups             = ["${aws_security_group.masters-k8s-pokedextracker-com.id}"]
  associate_public_ip_address = true
  user_data                   = "${file("${path.module}/data/aws_launch_configuration_master-us-west-2a.masters.k8s.pokedextracker.com_user_data")}"

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

resource "aws_launch_configuration" "nodes-k8s-pokedextracker-com" {
  name_prefix                 = "nodes.k8s.pokedextracker.com-"
  image_id                    = "ami-a1e199d9"
  instance_type               = "t2.medium"
  key_name                    = "${aws_key_pair.kubernetes-k8s-pokedextracker-com-6aa30f40dd576a5acb4943581ef88bca.id}"
  iam_instance_profile        = "${aws_iam_instance_profile.nodes-k8s-pokedextracker-com.id}"
  security_groups             = ["${aws_security_group.nodes-k8s-pokedextracker-com.id}"]
  associate_public_ip_address = true
  user_data                   = "${file("${path.module}/data/aws_launch_configuration_nodes.k8s.pokedextracker.com_user_data")}"

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

resource "aws_route53_record" "k8s-pokedextracker-com" {
  name = "k8s.pokedextracker.com"
  type = "A"

  alias = {
    name                   = "${aws_elb.api-k8s-pokedextracker-com.dns_name}"
    zone_id                = "${aws_elb.api-k8s-pokedextracker-com.zone_id}"
    evaluate_target_health = false
  }

  zone_id = "/hostedzone/Z1X7S3HZAHV4ZZ"
}

resource "aws_security_group" "api-elb-k8s-pokedextracker-com" {
  name        = "api-elb.k8s.pokedextracker.com"
  vpc_id      = "vpc-587db021"
  description = "Security group for api ELB"

  tags = {
    KubernetesCluster                              = "k8s.pokedextracker.com"
    Name                                           = "api-elb.k8s.pokedextracker.com"
    "kubernetes.io/cluster/k8s.pokedextracker.com" = "owned"
  }
}

resource "aws_security_group" "masters-k8s-pokedextracker-com" {
  name        = "masters.k8s.pokedextracker.com"
  vpc_id      = "vpc-587db021"
  description = "Security group for masters"

  tags = {
    KubernetesCluster                              = "k8s.pokedextracker.com"
    Name                                           = "masters.k8s.pokedextracker.com"
    "kubernetes.io/cluster/k8s.pokedextracker.com" = "owned"
  }
}

resource "aws_security_group" "nodes-k8s-pokedextracker-com" {
  name        = "nodes.k8s.pokedextracker.com"
  vpc_id      = "vpc-587db021"
  description = "Security group for nodes"

  tags = {
    KubernetesCluster                              = "k8s.pokedextracker.com"
    Name                                           = "nodes.k8s.pokedextracker.com"
    "kubernetes.io/cluster/k8s.pokedextracker.com" = "owned"
  }
}

resource "aws_security_group_rule" "all-master-to-master" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}

resource "aws_security_group_rule" "all-master-to-node" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}

resource "aws_security_group_rule" "all-node-to-node" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}

resource "aws_security_group_rule" "api-elb-egress" {
  type              = "egress"
  security_group_id = "${aws_security_group.api-elb-k8s-pokedextracker-com.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https-api-elb-136-24-25-248--32" {
  type              = "ingress"
  security_group_id = "${aws_security_group.api-elb-k8s-pokedextracker-com.id}"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["136.24.25.248/32"]
}

resource "aws_security_group_rule" "https-elb-to-master" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.api-elb-k8s-pokedextracker-com.id}"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "master-egress" {
  type              = "egress"
  security_group_id = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node-egress" {
  type              = "egress"
  security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "node-to-master-protocol-ipip" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "4"
}

resource "aws_security_group_rule" "node-to-master-tcp-1-2379" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port                = 1
  to_port                  = 2379
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "node-to-master-tcp-2382-4001" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port                = 2382
  to_port                  = 4001
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "node-to-master-tcp-4003-65535" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port                = 4003
  to_port                  = 65535
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "node-to-master-udp-1-65535" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  source_security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port                = 1
  to_port                  = 65535
  protocol                 = "udp"
}

resource "aws_security_group_rule" "ssh-external-to-master-136-24-25-248--32" {
  type              = "ingress"
  security_group_id = "${aws_security_group.masters-k8s-pokedextracker-com.id}"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["136.24.25.248/32"]
}

resource "aws_security_group_rule" "ssh-external-to-node-136-24-25-248--32" {
  type              = "ingress"
  security_group_id = "${aws_security_group.nodes-k8s-pokedextracker-com.id}"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["136.24.25.248/32"]
}

terraform = {
  required_version = ">= 0.9.3"
}
