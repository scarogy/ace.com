# EKS + Terraform Baseline (Prod-Ready)
Features:
- VPC, EKS (IRSA), ALB Controller, external-dns, ACM (per-env), Observability (Fluent Bit + SNS)
- RDS Postgres (private, encrypted, backups) + Secrets Manager
- External Secrets Operator (IRSA) to sync DB creds to Kubernetes
- Helm chart (nginx by default) with HTTPS Ingress
- dev/stg/prod with S3/DynamoDB remote state (bootstrap stack included)
- CI/CD (GitHub OIDC): infra plan/apply + app deploy; marketplace chart packaging
See docs/prereqs.md for setup.

Modified Test