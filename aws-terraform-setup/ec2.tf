# -----------------------------------------------------------------------------
# Windows Server 2022 AMI
# il-central-1 has Windows Server AMIs available from Amazon.
# -----------------------------------------------------------------------------

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# -----------------------------------------------------------------------------
# Domain Controller EC2 Instance
# - No public IP (Horizon egress: firewall → NAT → IGW)
# - All volumes encrypted (Horizon SCP enforces this)
# - SSM Session Manager is the only way in
# - key_pair is optional (only needed to decrypt initial admin password)
# -----------------------------------------------------------------------------

resource "aws_instance" "dc" {

  ami                    = data.aws_ami.windows_2022.id
  instance_type          = var.dc_instance_type
  subnet_id              = data.aws_subnet.dc.id
  vpc_security_group_ids = [aws_security_group.dc.id]
  iam_instance_profile   = aws_iam_instance_profile.dc.name

  associate_public_ip_address = true

  # Key pair — optional, only for decrypting initial Administrator password
  key_name = var.key_pair_name != "" ? var.key_pair_name : null

  # Root volume — MUST be encrypted or SCP will deny creation
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true

    tags = { Name = "${var.dc_hostname}-root" }
  }

  # IMDSv2 — more secure
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = templatefile("${path.module}/scripts/bootstrap-winrm.ps1", {
    hostname       = var.dc_hostname
    domain_name    = var.domain_name
    domain_netbios = var.domain_netbios
    dsrm_password  = random_password.dsrm.result
  })

  tags = {
    Name = var.dc_hostname
    Role = "domain-controller"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# -----------------------------------------------------------------------------
# Dedicated EBS volume for NTDS + SYSVOL
# Encrypted — mandatory in Horizon
# -----------------------------------------------------------------------------

resource "aws_ebs_volume" "ntds" {
  availability_zone = aws_instance.dc.availability_zone
  size              = var.ntds_volume_size
  type              = "gp3"
  encrypted         = true

  tags = { Name = "${var.dc_hostname}-ntds" }
}

resource "aws_volume_attachment" "ntds" {
  device_name  = "/dev/xvdf"
  volume_id    = aws_ebs_volume.ntds.id
  instance_id  = aws_instance.dc.id
  force_detach = false
}
