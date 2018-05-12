terraform {
  backend "s3" {
    bucket  = "terraform.pokedextracker.com"
    encrypt = true
    key     = "network.tfstate"
    region  = "us-west-2"
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  name       = "pokedextracker"
  cidr_block = "10.1.0.0/16"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block                       = "${local.cidr_block}"
  assign_generated_ipv6_cidr_block = false
  enable_classiclink               = false
  enable_classiclink_dns_support   = false
  enable_dns_hostnames             = true
  enable_dns_support               = true

  tags = {
    Name    = "${local.name}"
    Project = "PokedexTracker"
  }
}

resource "aws_subnet" "public" {
  count = "${length(data.aws_availability_zones.available.names)}"

  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${cidrsubnet(local.cidr_block, 8, count.index)}"
  availability_zone       = "${element(data.aws_availability_zones.available.names, count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${local.name}-${format("public-%03d", count.index + 1)}"
    Project = "PokedexTracker"
  }
}

resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.available.names)}"

  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${cidrsubnet(local.cidr_block, 8, count.index + 128)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags = {
    Name    = "${local.name}-${format("private-%03d", count.index + 1)}"
    Project = "PokedexTracker"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name    = "${local.name}"
    Project = "PokedexTracker"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name    = "${local.name}-public"
    Project = "PokedexTracker"
  }
}

resource "aws_route" "public" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

resource "aws_route_table_association" "public" {
  count = "${length(data.aws_availability_zones.available.names)}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}
