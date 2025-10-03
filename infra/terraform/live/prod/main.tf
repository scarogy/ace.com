module "vpc" {
  source          = "../../modules/vpc"
  name            = var.name
  cidr_block      = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  enable_nat      = var.enable_nat
}

module "iam" {
  source      = "../../modules/iam"
  name        = var.name
  github_org  = "your-org"
  github_repo = "your-repo"
}

module "eks" {
  source              = "../../modules/eks"
  name                = var.name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  node_instance_types = var.node_instance_types
  desired_size        = var.desired_size
}

module "eks_addons" {
  source             = "../../modules/eks-addons"
  name               = var.name
  cluster_name       = module.eks.cluster_name
  cluster_oidc_arn   = module.eks.oidc_provider_arn
  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  domain_suffix      = var.domain_suffix
}

module "acm" {
  source         = "../../modules/acm"
  domain         = var.env_host
  hosted_zone_id = var.hosted_zone_id
}

module "observability" {
  source       = "../../modules/observability"
  name         = var.name
  cluster_name = module.eks.cluster_name
}

resource "aws_ecr_repository" "ecommerce" {
  name = "ecommerce"
  image_scanning_configuration { scan_on_push = true }
}
output "ecr_repo" { value = aws_ecr_repository.ecommerce.repository_url }

resource "helm_release" "ecommerce" {
  name             = "ecommerce"
  chart            = "${path.module}/../../../apps/ecommerce/chart"
  namespace        = "ecommerce"
  create_namespace = true
  values = [yamlencode({
    image = {
      repository = "ghcr.io/nginxinc/nginx-unprivileged"
      tag        = "stable"
      pullPolicy = "IfNotPresent"
    }
    ingress = {
      enabled = true
      host    = var.env_host
      alb = {
        annotations = {
          "kubernetes.io/ingress.class"           : "alb",
          "alb.ingress.kubernetes.io/listen-ports": "[{\"HTTP\":80},{\"HTTPS\":443}]",
          "alb.ingress.kubernetes.io/certificate-arn": module.acm.certificate_arn,
          "alb.ingress.kubernetes.io/ssl-redirect": "443",
          "alb.ingress.kubernetes.io/scheme"      : "internet-facing",
          "alb.ingress.kubernetes.io/target-type" : "ip"
        }
      }
    }
  })]
  depends_on = [module.eks_addons]
}

# RDS (Postgres) + Secrets Manager
module "rds" {
  source               = "../../modules/rds"
  enabled              = true
  name                 = var.name
  vpc_id               = module.vpc.id
  private_subnet_ids   = module.vpc.private_subnet_ids
  ingress_security_group_ids = [module.eks.cluster_security_group_id]
  deletion_protection  = true
}

# External Secrets (grant access to RDS secret only)
module "eks_addons_es" {
  source             = "../../modules/eks-addons"
  name               = "${var.name}-es"
  cluster_name       = module.eks.cluster_name
  cluster_oidc_arn   = module.eks.oidc_provider_arn
  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  domain_suffix      = var.domain_suffix
  external_secrets_secret_arns = [ module.rds.secret_arn ]
}

# SecretStore + ExternalSecret
resource "kubernetes_manifest" "secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = { name = "aws-secrets", namespace = "ecommerce" }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = { jwt = { serviceAccountRef = { name = "external-secrets" } } }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "db_secret" {
  depends_on = [ kubernetes_manifest.secret_store ]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = { name = "db-credentials", namespace = "ecommerce" }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = { name = "aws-secrets", kind = "SecretStore" }
      target = { name = "db-credentials", creationPolicy = "Owner" }
      data = [{ secretKey = "db.json", remoteRef = { key = module.rds.secret_name } }]
    }
  }
}

# One-off DB connectivity Job
resource "kubernetes_manifest" "db_test_job" {
  depends_on = [ kubernetes_manifest.db_secret ]
  manifest = {
    apiVersion = "batch/v1"
    kind = "Job"
    metadata = { name = "db-connect-test", namespace = "ecommerce" }
    spec = {
      backoffLimit = 1
      template = {
        metadata = { name = "db-connect-test" }
        spec = {
          restartPolicy = "Never"
          containers = [{
            name  = "psql"
            image = "postgres:15"
            command = ["bash","-lc","set -e; apt-get update >/dev/null 2>&1 || true; echo running; cat /creds/db.json | jq -r '.password' >/tmp/pw; PGPASSWORD=$(cat /tmp/pw) psql -h {" + "module.rds.endpoint" + "} -U appuser -d appdb -c 'SELECT 1;'"]
            volumeMounts = [{ name = "creds", mountPath = "/creds" }]
          }]
          volumes = [{ name = "creds", secret = { secretName = "db-credentials", items = [{ key = "db.json", path = "db.json" }] } }]
        }
      }
    }
  }
}

output "env_url" { value = "https://www.example.com" }
