variable "allowed_cidr_blocks" {
  type = list(string)
}

variable "ami_id" {}

variable "dns_zone_id" {}

variable "key_name" {}

variable "kubernetes_version" {}

variable "master_count" {}

variable "name" {}

variable "pod_subnet" {
  default = "192.168.0.0/16"
}

variable "service_subnet" {
  default = "10.96.0.0/16"
}

# We're only using 1 subnet so that our PVCs will easily be reattched if we need
# to cycle the node.
variable "subnet_id" {}

variable "worker_count" {}
