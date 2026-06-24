#!/usr/bin/env bash
# One-time setup: creates the S3 bucket + DynamoDB table that Terraform
# remote state relies on. Run this ONCE, manually, from your own
# machine with AWS CLI configured (not from CI - this is the chicken-
# and-egg resource Terraform itself can't manage before it has a
# backend to store state in).
#
# Usage: ./scripts/bootstrap_backend.sh <unique-suffix> <aws-region>
# Example: ./scripts/bootstrap_backend.sh myteam2026 us-east-1

set -euo pipefail

SUFFIX="${1:?Usage: $0 <unique-suffix> <aws-region>}"
REGION="${2:-us-east-1}"

BUCKET="ha-app-tfstate-${SUFFIX}"
TABLE="ha-app-tf-lock-${SUFFIX}"

echo "Creating state bucket: ${BUCKET} in ${REGION}"
if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Creating DynamoDB lock table: ${TABLE}"
aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

cat <<EOF

Done. Now edit terraform/backend.tf:

terraform {
  backend "s3" {
    bucket         = "${BUCKET}"
    key            = "aws-ha-devops-project/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${TABLE}"
    encrypt        = true
  }
}

Then uncomment the block and run: terraform init
EOF
