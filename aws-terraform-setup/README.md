# AD Domain Controller on AWS Horizon Landing Zone

Deploys a single Windows Server 2022 Domain Controller into the Horizon LZ
pre-provisioned VPC in `il-central-1`.

## Horizon LZ Constraints Respected

- **No VPC/subnet/route/IGW/NAT creation** — uses `data` sources to discover existing
- **No Route53** — restricted service; AD DNS runs on the DC itself
- **No IAM Users** — only IAM roles (SCP enforced)
- **No public IPs** — access via SSM Session Manager only
- **All EBS encrypted** — SCP enforced
- **No ELB/CloudFront/API GW** — restricted services
- **No Marketplace purchases** — use Private Marketplace via FinOps

## Prerequisites

1. Horizon account with admin permissions (`HZN-<ProjectName>-PRD-Admins`)
2. AWS CLI v2 + Session Manager plugin installed locally
3. SSO login: `aws sso login --profile horizon`
4. A key pair in `il-central-1` (for initial password decryption)

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — check subnet tag names in your VPC console

terraform init
terraform plan
terraform apply
```

## Connect

After deploy, the instance needs 5-10 minutes to boot, run user_data, and register
with SSM.

```bash
# RDP (in one terminal):
eval "$(terraform output -raw ssm_rdp_command)"
# Then RDP to localhost:13389

# WinRM for Ansible (in one terminal):
eval "$(terraform output -raw ssm_winrm_command)"
# Then run Ansible against localhost:15986 — see ansible_inventory_snippet output
```

## Initial Admin Password

```bash
aws ec2 get-password-data \
  --instance-id "$(terraform output -raw dc_instance_id)" \
  --priv-launch-key ~/path-to/my-key.pem \
  --region il-central-1
```

## Next Step: Ansible

Terraform only provisions the infrastructure. DC promotion is done via Ansible
using `microsoft.ad.domain` and `microsoft.ad.domain_controller` modules.
