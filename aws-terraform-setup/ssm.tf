# -----------------------------------------------------------------------------
# Secrets in SSM Parameter Store
# DSRM password auto-generated and stored as SecureString.
# Ansible pulls it during DC promotion.
# -----------------------------------------------------------------------------

resource "random_password" "dsrm" {
  length           = 24
  special          = true
  override_special = "!@#$%^&*"
}

resource "aws_ssm_parameter" "dsrm_password" {
  name        = "/ad/dsrm-password"
  description = "Directory Services Restore Mode password"
  type        = "SecureString"
  value       = random_password.dsrm.result

  tags = { Name = "ad-dsrm-password" }
}

resource "aws_ssm_parameter" "domain_name" {
  name        = "/ad/domain-name"
  description = "AD domain FQDN"
  type        = "String"
  value       = var.domain_name

  tags = { Name = "ad-domain-name" }
}

resource "aws_ssm_parameter" "domain_netbios" {
  name        = "/ad/domain-netbios"
  description = "AD domain NetBIOS name"
  type        = "String"
  value       = var.domain_netbios

  tags = { Name = "ad-domain-netbios" }
}
