# Remote state backend.
#
# Real-world standard: never use local state for anything beyond a
# personal experiment. State is stored in S3 (versioned + encrypted)
# with a DynamoDB table for state locking so two people/pipelines
# can't run `terraform apply` at the same time and corrupt state.
#
# The bucket/table referenced here must already exist before you run
# `terraform init` - create them first with scripts/bootstrap_backend.sh.

terraform {
  backend "s3" {
    bucket         = "ha-app-tfstate-ytagne2026"
    key            = "aws-ha-devops-project/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ha-app-tf-lock-ytagne2026"
    encrypt        = true
  }
}
