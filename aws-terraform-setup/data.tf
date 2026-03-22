# -----------------------------------------------------------------------------
# Discover the Horizon LZ pre-provisioned networking
# The Platform Team creates the VPC, subnets, firewall, NAT, and IGW.
# We just need to find them and deploy into the private/compute subnet.
# -----------------------------------------------------------------------------

# Find the VPC — Horizon creates one per account
data "aws_vpcs" "all" {}

data "aws_vpc" "horizon" {
  id = tolist(data.aws_vpcs.all.ids)[0]
}

# Find all subnets in the VPC
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.horizon.id]
  }
}

# Find the private/compute subnet by tag name
# Horizon architecture: protected subnet, NAT subnet, private subnet (compute)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.horizon.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*${var.private_subnet_tag_filter}*"]
  }
}

# Grab the first matching private subnet
data "aws_subnet" "dc" {
  id = tolist(data.aws_subnets.private.ids)[0]
}

# Current account identity
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
