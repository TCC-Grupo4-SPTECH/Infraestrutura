terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  effective_lab_role_arn = coalesce(
    var.lab_role_arn,
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.lab_role_name}"
  )
}