# -----------------------------------------------------------------------------
# Security Group for the DC
# No public access — everything is within the VPC.
# Admin access is via SSM Session Manager (no inbound ports needed for that).
# AD ports are open within the VPC CIDR for future member servers.
# -----------------------------------------------------------------------------

resource "aws_security_group" "dc" {
  name_prefix = "ad-dc-"
  description = "Domain Controller - AD ports within VPC"
  vpc_id      = data.aws_vpc.horizon.id

  tags = { Name = "ad-dc-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- AD ports within the VPC ---

locals {
  vpc_cidr = data.aws_vpc.horizon.cidr_block

  ad_tcp_ports = {
    dns       = 53
    kerberos  = 88
    rpc_epmap = 135
    ldap      = 389
    smb       = 445
    kpasswd   = 464
    ldaps     = 636
    gc        = 3268
    gc_ssl    = 3269
    adws      = 9389
    winrm_h   = 5985
    winrm_s   = 5986
  }

  ad_udp_ports = {
    dns      = 53
    kerberos = 88
    ntp      = 123
    ldap     = 389
    kpasswd  = 464
  }
}

resource "aws_vpc_security_group_ingress_rule" "ad_tcp" {
  for_each = local.ad_tcp_ports

  security_group_id = aws_security_group.dc.id
  description       = "AD ${each.key} TCP"
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr
}

resource "aws_vpc_security_group_ingress_rule" "ad_udp" {
  for_each = local.ad_udp_ports

  security_group_id = aws_security_group.dc.id
  description       = "AD ${each.key} UDP"
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "udp"
  cidr_ipv4         = local.vpc_cidr
}

# RPC dynamic range
resource "aws_vpc_security_group_ingress_rule" "rpc_dynamic" {
  security_group_id = aws_security_group.dc.id
  description       = "RPC dynamic range"
  from_port         = 49152
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr
}

# RDP from anywhere (public access)
resource "aws_vpc_security_group_ingress_rule" "rdp" {
  security_group_id = aws_security_group.dc.id
  description       = "RDP from anywhere"
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Egress: allow all outbound (goes through Horizon firewall → NAT → IGW) ---

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.dc.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
