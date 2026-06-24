# Highly Available AWS App Infrastructure

A small Flask app, deployed on EC2 behind a public Application Load
Balancer, spread across 2 Availability Zones, provisioned with
Terraform, and deployed via GitHub Actions using OIDC (no long-lived
AWS keys).

See the accompanying step-by-step guide document for the full
walkthrough, a 2-week build plan, and the reasoning behind the
security/HA decisions made here. This README is just a quick map of
the repo.

## Layout

```
terraform/
  main.tf, variables.tf, outputs.tf, providers.tf, backend.tf
  modules/
    network/        VPC, public+private subnets (2 AZs), IGW, NAT
    security/        Security groups, EC2 IAM role (SSM, no SSH)
    loadbalancer/    Public ALB, target group, listeners
    compute/         Launch template, Auto Scaling Group, scaling policy
app/
  app.py             Flask app (/ and /health)
  requirements.txt
  test_app.py
.github/workflows/
  ci.yml             Lint + test the app
  app-deploy.yml      Package app, upload to S3, roll out via instance refresh
  infra.yml           terraform fmt/validate/plan (PRs), apply (main, with approval)
scripts/
  bootstrap_backend.sh                One-time: create the Terraform state bucket + lock table
  setup_github_oidc.sh                One-time: create the GitHub OIDC provider + IAM role
  github-actions-trust-policy.json.tpl
  github-actions-permissions-policy.json
```

## Quick start

1. `./scripts/bootstrap_backend.sh <your-unique-suffix> us-east-1`
2. Edit `terraform/backend.tf` with the bucket/table names it printed, uncomment the block.
3. `./scripts/setup_github_oidc.sh <github-org> <github-repo>`
4. Add the printed `AWS_ROLE_ARN` (and later, `ARTIFACT_BUCKET` / `ASG_NAME` from `terraform output`) as repo variables in GitHub Settings -> Secrets and variables -> Actions -> Variables.
5. Create a GitHub Environment named `production` with required reviewers.
6. `cd terraform && cp terraform.tfvars.example terraform.tfvars` and edit as needed.
7. `terraform init && terraform plan && terraform apply` (or just open a PR and let `infra.yml` do it).
8. Push a change under `app/` to main - `ci.yml` then `app-deploy.yml` will build, ship, and roll it out.
9. Open the `alb_dns_name` Terraform output in a browser.

Full details, screenshots-style walkthrough, and the day-by-day 2-week plan are in the guide document.
