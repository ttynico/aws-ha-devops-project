#!/usr/bin/env bash
# One-time setup: registers GitHub Actions as an OIDC identity
# provider in your AWS account and creates an IAM role it can assume.
# This is the real-world-standard alternative to storing long-lived
# AWS access keys as GitHub secrets.
#
# Usage: ./scripts/setup_github_oidc.sh <github-org> <github-repo>
# Example: ./scripts/setup_github_oidc.sh myusername aws-ha-devops-project

set -euo pipefail

GH_ORG="${1:?Usage: $0 <github-org> <github-repo>}"
GH_REPO="${2:?Usage: $0 <github-org> <github-repo>}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Account: ${ACCOUNT_ID}"
echo "Repo:    ${GH_ORG}/${GH_REPO}"

# 1. Create the OIDC provider (skip if it already exists in your account -
#    there can only be one provider per issuer URL per account).
EXISTING=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" \
  --output text || true)

if [[ -z "$EXISTING" ]]; then
  echo "Creating GitHub OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
    # Note: AWS validates GitHub's OIDC certificate chain automatically
    # now; the thumbprint is effectively a legacy required field. If
    # this command errors on the thumbprint, check AWS's current docs -
    # the API may have changed since this script was written.
else
  echo "OIDC provider already exists: ${EXISTING}"
fi

# 2. Render the trust policy with your account/org/repo filled in.
sed -e "s/__ACCOUNT_ID__/${ACCOUNT_ID}/" \
    -e "s/__GITHUB_ORG__/${GH_ORG}/" \
    -e "s/__GITHUB_REPO__/${GH_REPO}/" \
    "$(dirname "$0")/github-actions-trust-policy.json.tpl" > /tmp/trust-policy.json

# 3. Create the role + attach the permissions policy.
ROLE_NAME="ha-app-github-actions"

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --description "Assumed by GitHub Actions OIDC to deploy ha-app infra"

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "ha-app-deploy-permissions" \
  --policy-document "file://$(dirname "$0")/github-actions-permissions-policy.json"

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

cat <<EOF

Done. Role ARN: ${ROLE_ARN}

Now in your GitHub repo: Settings -> Secrets and variables -> Actions -> Variables tab,
add these repository variables (NOT secrets - they aren't sensitive, but using
"vars" instead of "secrets" makes that explicit):

  AWS_ROLE_ARN     = ${ROLE_ARN}
  ARTIFACT_BUCKET  = (the artifact_bucket output from 'terraform output' after first apply)
  ASG_NAME         = (the asg_name output from 'terraform output' after first apply)

Then in repo Settings -> Environments, create an environment named "production"
and add required reviewers if you want a human approval gate before
terraform apply / app deploys run.
EOF
