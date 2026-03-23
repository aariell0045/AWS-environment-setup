# =============================================================================
# terraform.tfvars.example — Horizon Landing Zone
# Copy to terraform.tfvars and fill in your values.
#
# NOTE: Region is hardcoded to il-central-1 in main.tf.
# NOTE: VPC/subnets are discovered automatically from the Horizon LZ.
# =============================================================================

environment = "lab"

# --- VPC discovery ---
# Tag Name filter to find the Horizon-provisioned VPC (leave empty to pick the first VPC)
vpc_tag_filter = ""

# --- Deployment toggle ---
# Set to true to deploy the EC2 instance and EBS volume. false = no billable compute resources.
instance_enabled = false

# --- Domain ---
domain_name    = "ds.team"
domain_netbios = "DS"
dc_hostname    = "lab-DC1"

# --- EC2 ---
dc_instance_type = "t3.small"     # 2 vCPU, 2 GB — sufficient for lab/learning
ntds_volume_size = 10

# Key pair — must already exist in il-central-1.
# Only needed to decrypt the initial Administrator password from EC2 console.
# If you don't have one, create it first:
#   aws ec2 create-key-pair --key-name my-key --region il-central-1 --query 'KeyMaterial' --output text > my-key.pem
key_pair_name = "tomerandariel"

# --- Subnet discovery ---
# The filter matches subnet Name tags containing this string.
# Check your Horizon account's subnet names in the VPC console and adjust if needed.
# Common patterns: "Private", "private", "compute"
private_subnet_tag_filter = "SPOKE-Networking-922384915313-Stack/VPC/VPC/firewallSubnet2"
