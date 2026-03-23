# -----------------------------------------------------------------------------
# IAM Role for the DC instance
# - SSM Session Manager (remote access without public ports)
# - SSM Parameter Store (DSRM password, domain config)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "dc" {
  name_prefix = "ad-dc-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SSM Session Manager
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.dc.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# SSM Parameter Store — read DSRM password and domain config
resource "aws_iam_role_policy" "ssm_params" {
  name_prefix = "ssm-params-"
  role        = aws_iam_role.dc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
      ]
      Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/ad/*"
    }]
  })
}

resource "aws_iam_instance_profile" "dc" {
  name_prefix = "ad-dc-"
  role        = aws_iam_role.dc.name
}
