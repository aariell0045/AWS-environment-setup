terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment for remote state — make sure the S3 bucket exists
  # and has encryption enabled (SCP requirement)
  # backend "s3" {
  #   bucket  = "my-tf-state"
  #   key     = "dc-deploy/terraform.tfstate"
  #   region  = "il-central-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region = "il-central-1"

  default_tags {
    tags = {
      Project     = "ad-domain"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
