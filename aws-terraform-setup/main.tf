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

  backend "s3" {
    # Override any of these at init time:
    #   terraform init -backend-config="bucket=<your-bucket>" \
    #                  -backend-config="dynamodb_table=<your-table>"
    bucket         = "my-tf-state"
    key            = "ad-lab/terraform.tfstate"
    region         = "il-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
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
