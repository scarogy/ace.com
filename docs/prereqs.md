# Prereqs
- AWS account + admin for bootstrap; least-priv after.
- Route53 hosted zone (domain).
- Tools: Terraform >=1.6, AWS CLI v2, kubectl, helm, tflint, checkov, Go (optional).
- GitHub repo with Actions enabled; Environments: dev, stg, prod (approvals for stg/prod).

## Steps
1) Bootstrap remote state:
   ```bash
   cd infra/bootstrap
   terraform init
   terraform apply -auto-approve -var 'bucket_name=tfstate-<org>' -var 'region=us-east-1'
   ```
2) In each env under `infra/terraform/live/{env}` edit:
   - `backend.hcl` (bucket name from bootstrap)
   - `{env}.tfvars` (`region`, VPC CIDRs, `hosted_zone_id`, `env_host`)
3) Apply dev:
   ```bash
   cd infra/terraform/live/dev
   terraform init -backend-config=backend.hcl
   terraform apply -auto-approve -var-file=dev.tfvars
   aws eks update-kubeconfig --name eks-dev --region us-east-1
   ```
4) Set GitHub Secrets: AWS_ROLE_GITHUB_DEV/STG/PROD, EKS_CLUSTER_NAME_DEV/STG/PROD, DEV_HOST/STG_HOST/PROD_HOST, ECR_REPO.
5) Use CI workflows for plans/applies and app deploys.
