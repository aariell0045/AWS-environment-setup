# -----------------------------------------------------------------------------
# Outputs
# No public IPs in Horizon — everything goes through SSM.
# -----------------------------------------------------------------------------

output "dc_instance_id" {
  description = "EC2 instance ID (use this for SSM session)"
  value       = try(aws_instance.dc[0].id, null)
}

output "dc_private_ip" {
  description = "Private IP of the domain controller"
  value       = try(aws_instance.dc[0].private_ip, null)
}

output "dc_hostname" {
  description = "Windows hostname"
  value       = var.dc_hostname
}

output "domain_name" {
  description = "AD domain FQDN"
  value       = var.domain_name
}

output "dsrm_password_ssm_path" {
  description = "SSM Parameter Store path for the DSRM password"
  value       = aws_ssm_parameter.dsrm_password.name
}

output "vpc_id" {
  description = "Horizon-provisioned VPC ID"
  value       = data.aws_vpc.horizon.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = data.aws_vpc.horizon.cidr_block
}

output "subnet_id" {
  description = "Private/compute subnet ID where DC is deployed"
  value       = data.aws_subnet.dc.id
}

output "security_group_id" {
  description = "DC security group ID"
  value       = aws_security_group.dc.id
}

# --- SSM connection instructions ---

output "ssm_rdp_command" {
  description = "Start an SSM port-forwarding session for RDP"
  value       = var.instance_enabled ? "aws ssm start-session --target ${aws_instance.dc[0].id} --document-name AWS-StartPortForwardingSession --parameters portNumber=3389,localPortNumber=13389 --region il-central-1" : null
}

output "ssm_winrm_command" {
  description = "Start an SSM port-forwarding session for WinRM (Ansible)"
  value       = var.instance_enabled ? "aws ssm start-session --target ${aws_instance.dc[0].id} --document-name AWS-StartPortForwardingSession --parameters portNumber=5986,localPortNumber=15986 --region il-central-1" : null
}

output "ansible_inventory_snippet" {
  description = "Ansible inventory — connect through SSM port forward on localhost:15986"
  value       = <<-EOT
    [domain_controllers]
    ${var.dc_hostname} ansible_host=127.0.0.1

    [domain_controllers:vars]
    ansible_connection=winrm
    ansible_port=15986
    ansible_winrm_transport=ntlm
    ansible_winrm_server_cert_validation=ignore
    ansible_user=Administrator
    # ansible_password=<decrypt from EC2 console with your key pair>
    # Run the ssm_winrm_command output in a separate terminal first!
  EOT
}
