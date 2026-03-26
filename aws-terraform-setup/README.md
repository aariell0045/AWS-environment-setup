# AD Lab Environment on AWS

Deploys a full Active Directory lab with 4 Windows Server 2022 instances into the
Horizon LZ pre-provisioned VPC in `il-central-1`. All domain setup, domain joining,
and role configuration is fully automated via PowerShell user_data scripts (no Ansible needed).

## Instances

| Name | Role | Instance Type | What it does |
|------|------|---------------|--------------|
| DC01 | Domain Controller + DNS | t3.medium | Creates the AD forest, promotes to DC, creates `ds-admin` domain admin user |
| lab-DHCP1 | DHCP Server | t3.small | Joins domain, authorizes in AD, configures DHCP scope (192.168.10.100-.200) |
| lab-DFS1 | DFS Server | t3.small | Joins domain, creates DFS shared folders (Public, Departments) |
| lab-MGMT1 | Management Server | t3.small | Joins domain, installs all RSAT tools (AD, DNS, DHCP, DFS, GPO) |

## How It Works

Each instance uses a two-phase bootstrap script:

1. **Phase 1 (first boot):** Set hostname, enable RDP, install Windows roles, reboot
2. **Phase 2 (after reboot):** DC promotes to domain controller; member servers wait for the DC to be ready, then join the domain and configure their services

Member servers automatically wait up to 30 minutes for the DC to finish promoting before attempting to join the domain.

## Domain Details

| Setting | Default |
|---------|---------|
| Domain FQDN | `corp.local` |
| NetBIOS name | `CORP` |
| Domain admin user | `ds-admin` (member of Domain Admins + Enterprise Admins) |
| Domain admin password | Set via `domain_admin_password` variable |
| DSRM password | Auto-generated, stored in SSM at `/ad/dsrm-password` |

## Prerequisites

1. Horizon account with admin permissions
2. AWS CLI v2 configured for `il-central-1`
3. A key pair in `il-central-1` (optional, for initial password decryption)

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set domain_admin_password and check subnet tag names

terraform init
terraform plan
terraform apply
```

After `terraform apply`, allow ~20-30 minutes for the full environment to be ready
(DC promotion + all member servers joining the domain).

## Connect

All instances have public IPs and RDP enabled. Use the outputs to get the IPs:

```bash
# Get all public IPs
terraform output dc_public_ip
terraform output dhcp_public_ip
terraform output dfs_public_ip
terraform output mgmt_public_ip
```

RDP credentials:
- **Username:** `CORP\ds-admin` or `CORP\Administrator`
- **Password:** the `domain_admin_password` you set in tfvars

SSM is also available for port forwarding:

```bash
# RDP via SSM tunnel to the DC
eval "$(terraform output -raw ssm_rdp_command)"
# Then RDP to localhost:13389
```

## Outputs

| Output | Description |
|--------|-------------|
| `dc_instance_id` / `dc_public_ip` | DC instance ID and public IP |
| `dhcp_instance_id` / `dhcp_public_ip` | DHCP server instance ID and public IP |
| `dfs_instance_id` / `dfs_public_ip` | DFS server instance ID and public IP |
| `mgmt_instance_id` / `mgmt_public_ip` | Management server instance ID and public IP |
| `domain_name` | AD domain FQDN |
| `dsrm_password_ssm_path` | SSM path for DSRM password |
| `vpc_id` / `subnet_id` | Network info |
