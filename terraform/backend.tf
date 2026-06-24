# Remote state backend.
#
# Real-world standard: never use local state for anything beyond a
# personal experiment. State is stored in S3 (versioned + encrypted)
# with a DynamoDB table for state locking so two people/pipelines
# can't run `terraform apply` at the same time and corrupt state.
#
# The bucket/table referenced here must already exist before you run
# `terraform init` - create them first with scripts/bootstrap_backend.sh.
#
# Fill in the bucket name (must be globally unique) and table name,
# then uncomment this block. Terraform backend blocks cannot use
# variables, so the values are hard-coded here intentionally.

# terraform {
#   backend "s3" {
#     bucket         = "REPLACE-ME-tfstate-bucket"
#     key            = "aws-ha-devops-project/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "REPLACE-ME-tf-lock-table"
#     encrypt        = true
#   }
# }
