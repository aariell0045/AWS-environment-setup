variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

# --- VPC discovery ---
# The Horizon LZ pre-provisions a VPC in your account.
# We find it by tag or by being the only VPC present.

variable "vpc_tag_filter" {
  description = "Tag Name filter to find the Horizon-provisioned VPC (leave empty to pick the first VPC)"
  type        = string
  default     = ""
}

variable "private_subnet_tag_filter" {
  description = "Tag Name filter to find the private/compute subnet (e.g. 'Private' or 'private')"
  type        = string
  default     = "rivate" # matches 'Private' or 'private' via wildcard
}

# --- Domain ---

variable "domain_name" {
  description = "FQDN for the new AD domain"
  type        = string
  default     = "corp.local"
}

variable "domain_netbios" {
  description = "NetBIOS name for the domain"
  type        = string
  default     = "CORP"
}

variable "dc_hostname" {
  description = "Windows hostname for the DC (max 15 chars)"
  type        = string
  default     = "DC01"
}

# --- Deployment toggle ---

variable "instance_enabled" {
  description = "Set to true to deploy the EC2 instance and EBS volume. false = no billable compute resources."
  type        = bool
  default     = false
}

# --- EC2 ---

variable "dc_instance_type" {
  description = "EC2 instance type — t3.medium is the cheapest practical size for a DC"
  type        = string
  default     = "t3.medium"
}

variable "ntds_volume_size" {
  description = "Size in GB for the NTDS/SYSVOL EBS volume"
  type        = number
  default     = 20
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name (for initial password decryption). Leave empty to skip."
  type        = string
  default     = ""
}
