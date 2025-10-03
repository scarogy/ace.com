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
  source = "../../modules/eks"

  name               = var.name
  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_version     = var.cluster_version
  node_instance_types = var.node_instance_types
  desired_size        = var.desired_size
}



module "eks_addons" {
  count              = var.enable_k8s ? 1 : 0
  source             = "../../modules/eks-addons"
  name               = var.name
  cluster_name       = module.eks.cluster_name
  cluster_oidc_arn   = module.eks.oidc_provider_arn
  cluster_oidc_url   = module.eks.cluster_oidc_issuer_url
  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  domain_suffix      = var.domain_suffix
  enable_external_dns = var.enable_dns
  enable_tls          = var.enable_tls


}

module "eks_addons_es" {
  count              = var.enable_k8s ? 1 : 0
  source             = "../../modules/eks-addons"
  name               = "${var.name}-es"
  cluster_name       = module.eks.cluster_name
  cluster_oidc_arn   = module.eks.oidc_provider_arn
  cluster_oidc_url   = module.eks.cluster_oidc_issuer_url
  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  domain_suffix      = var.domain_suffix
  external_secrets_secret_arns = [module.rds.secret_arn]
  enable_external_dns = var.enable_dns
  enable_tls          = var.enable_tls

}

# Wait for the External Secrets Helm release (module) to finish
resource "time_sleep" "wait_for_es_crds" {
  count           = var.enable_k8s ? 1 : 0
  depends_on      = [module.eks_addons_es]   # the Helm release that installs CRDs
  create_duration = "60s"
}

# Tag each PUBLIC subnet for EKS & ALB discovery
# Requires: module.vpc.public_subnet_ids and module.eks.cluster_name outputs.
resource "aws_ec2_tag" "public_cluster_shared" {
  for_each    = toset(module.vpc.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${module.eks.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_role_elb" {
  for_each    = toset(module.vpc.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}


# module "acm" {
#   source         = "../../modules/acm"
#   domain         = var.env_host
#   hosted_zone_id = var.hosted_zone_id
# }

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

# --- AWS Load Balancer Controller (Helm) ---

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"

  # Wait until it's ready
  wait    = true
  timeout = 600

  values = [yamlencode({
    clusterName = module.eks.cluster_name
    region      = data.aws_region.current.name
    vpcId       = module.vpc.id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
      }
    }
    # Disable cert-manager integration by default
    enableCertManager = false
  })]

  depends_on = [
    aws_iam_role.alb_controller,
    aws_ec2_tag.public_cluster_shared,
    aws_ec2_tag.public_role_elb
  ]
}

# resource "helm_release" "nginx" {
#   count      = var.enable_k8s ? 1 : 0
#   name       = "nginx"
#   repository = "https://charts.bitnami.com/bitnami"
#   chart      = "nginx"
#   namespace  = "ecommerce"
#   create_namespace = true

#   values = [yamlencode({
#     service = { type = "ClusterIP", ports = { http = 80 } }
#     resources = { requests = { cpu = "50m", memory = "64Mi" } }
#   })]
# }


# RDS (Postgres) + Secrets Manager
module "rds" {
  source               = "../../modules/rds"
  enabled              = true
  name                 = var.name
  vpc_id               = module.vpc.id
  private_subnet_ids   = module.vpc.private_subnet_ids
  ingress_security_group_ids = [module.eks.cluster_security_group_id]
  deletion_protection  = false
}

# Get the VPC so we can read its CIDR block
data "aws_vpc" "this" {
  id = module.vpc.id
}

# Allow Postgres from inside the VPC (dev-friendly)
resource "aws_security_group_rule" "db_ingress_from_vpc" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"

  security_group_id = module.rds.security_group_id   # ensure your RDS module outputs this
  cidr_blocks       = [data.aws_vpc.this.cidr_block] # ← use the data source CIDR, not module.vpc.cidr_block
}


# # SecretStore (only after CRDs exist)
# resource "kubernetes_manifest" "secret_store" {
#   count      = var.enable_k8s && var.enable_external_secrets_objects ? 1 : 0
#   depends_on = [time_sleep.wait_for_es_crds]

#   manifest = {
#     "apiVersion" = "external-secrets.io/v1beta1"
#     "kind"       = "SecretStore"
#     "metadata"   = { "name" = "aws-secrets", "namespace" = "ecommerce" }
#     "spec" = {
#       "provider" = {
#         "aws" = {
#           "service" = "SecretsManager"
#           "region"  = var.region
#           "auth" = {
#             "jwt" = {
#               "serviceAccountRef" = { "name" = "external-secrets", "namespace" = "ecommerce" }
#             }
#           }
#         }
#       }
#     }
#   }
# }

# # If you also create an ExternalSecret, gate it the same way:
# resource "kubernetes_manifest" "db_secret" {
#   count      = var.enable_k8s && var.enable_external_secrets_objects ? 1 : 0
#   depends_on = [kubernetes_manifest.secret_store]
#   manifest = {
#     "apiVersion" = "external-secrets.io/v1beta1"
#     "kind"       = "ExternalSecret"
#     "metadata"   = { "name" = "db-credentials", "namespace" = "ecommerce" }
#     "spec" = {
#       "refreshInterval" = "1h"
#       "secretStoreRef"  = { "name" = "aws-secrets", "kind" = "SecretStore" }
#       "target"          = { "name" = "db-credentials", "creationPolicy" = "Owner" }
#       "data" = [
#         { "secretKey" = "password", "remoteRef" = { "key" = module.rds.secret_name, "property" = "password" } },
#         { "secretKey" = "username", "remoteRef" = { "key" = module.rds.secret_name, "property" = "username" } },
#         { "secretKey" = "dbname",   "remoteRef" = { "key" = module.rds.secret_name, "property" = "dbname"   } }
#       ]
#     }
#   }
# }
resource "kubernetes_job" "db_connect_test" {
  count = var.enable_k8s ? 1 : 0

  metadata {
    name      = "db-connect-test"
    namespace = "ecommerce"
    labels = {
      app = "db-connect-test"
    }
  }

  # Prevents apply from failing while you debug the job
  wait_for_completion = false

  spec {
    backoff_limit              = 0
    ttl_seconds_after_finished = 60

    template {
      metadata {
        labels = { app = "db-connect-test" }
      }
      spec {
        restart_policy = "Never"

        container {
          name  = "psql"
          image = "postgres:15"

          command = [
            "bash","-lc",
            "set -euo pipefail; psql -h \"$PGHOST\" -p \"$PGPORT\" -U \"$PGUSER\" -d \"$PGDATABASE\" -c 'SELECT 1;'"
          ]

          env {
            name = "PGHOST"
            value_from {
              secret_key_ref {
                name = "db-credentials"
                key  = "host"
              }
            }
          }

          env {
            name = "PGPORT"
            value_from {
              secret_key_ref {
                name = "db-credentials"
                key  = "port"
              }
            }
          }

          env {
            name = "PGUSER"
            value_from {
              secret_key_ref {
                name = "db-credentials"
                key  = "username"
              }
            }
          }

          env {
            name = "PGDATABASE"
            value_from {
              secret_key_ref {
                name = "db-credentials"
                key  = "dbname"
              }
            }
          }

          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = "db-credentials"
                key  = "password"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.db_credentials]
}





output "env_url" { value = "https://dev.example.com" }




# Namespace for the app
resource "kubernetes_namespace" "ecommerce" {
  count = var.enable_k8s ? 1 : 0
  metadata {
    name = "ecommerce"
  }
}
resource "helm_release" "ecommerce_app" {
  count              = (var.enable_k8s && var.use_helm_app) ? 1 : 0

  name               = "wordpress"
  repository         = "https://charts.bitnami.com/bitnami"
  chart              = "wordpress"
  version            = "23.1.22"
  namespace          = "ecommerce"
  create_namespace   = false

values = [yamlencode({
  service = { 
    type = "ClusterIP"
    ports = { http = 80 }
  }

  wordpressUsername = "admin"
  wordpressPassword = "password"
  wordpressBlogName = "Demo on EKS"

  persistence       = { enabled = false }
  volumePermissions = { enabled = false }

  image = {
    registry   = "public.ecr.aws"
    repository = "bitnami/wordpress"
    pullPolicy = "IfNotPresent"
  }

  mariadb = {
    enabled = true
    volumePermissions = { enabled = false }
    
    image = {
      registry   = "public.ecr.aws"
      repository = "bitnami/mariadb"
      pullPolicy = "IfNotPresent"
    }
    
    auth = { 
      rootPassword = "supersecret123"
      username     = "bn_wordpress"
      password     = "password"
      database     = "bitnami_wordpress"
    }
    primary = {
      persistence = { enabled = false }
      resources   = { requests = { cpu = "50m", memory = "128Mi" } }
    }
  }

  resources = { requests = { cpu = "50m", memory = "256Mi" } }
})]


}


# Request ACM certificate once domain name is bought
# resource "aws_acm_certificate" "wordpress" {
#   domain_name       = "yourdomain.com"
#   validation_method = "DNS"

#   subject_alternative_names = [
#     "www.yourdomain.com"
#   ]

#   lifecycle {
#     create_before_destroy = true
#   }

#   tags = {
#     Name = "wordpress-cert"
#   }
# }

# # Create Route53 validation records (if using Route53)
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.wordpress.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = aws_route53_zone.main.zone_id
# }

# # Wait for validation
# resource "aws_acm_certificate_validation" "wordpress" {
#   certificate_arn         = aws_acm_certificate.wordpress.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }
# Helm release: WordPress (Bitnami)
# resource "helm_release" "ecommerce_app" {
#   count              = (var.enable_k8s && var.use_helm_app) ? 1 : 0

#   name               = "ecommerce"
#   repository         = "https://charts.bitnami.com/bitnami"
#   chart              = "wordpress"
#   version            = "23.1.22"  # Use newer version
#   namespace          = "ecommerce"
#   create_namespace   = true

#   wait               = false
#   timeout            = 1800
#   atomic             = false
#   force_update       = true
#   cleanup_on_fail    = true
#   dependency_update  = true

#   values = [yamlencode({
#     ingress = { enabled = false }
#     fullnameOverride = "nginx"
#     service = { type = "ClusterIP", ports = { http = 80 } }

#     wordpressUsername = "admin"
#     wordpressPassword = "password"
#     wordpressBlogName = "Demo on EKS"

#     persistence       = { enabled = false }
#     volumePermissions = { enabled = false }

#     # Don't override images - use chart defaults
    
#     mariadb = {
#       enabled = true
#       primary = {
#         persistence = { enabled = false }
#         resources   = { requests = { cpu = "50m", memory = "128Mi" } }
#       }
#       auth = { 
#         username = "bn_wordpress"
#         password = "password"
#         database = "bitnami_wordpress"
#       }
#     }

#     resources = { requests = { cpu = "50m", memory = "256Mi" } }
#   })]

#   depends_on = [kubernetes_namespace.ecommerce]
# }

# Read the secret JSON
data "aws_secretsmanager_secret_version" "db" {
  secret_id = module.rds.secret_arn
}

locals {
  db_secret = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)

  lb_public_subnets_csv = join(",", module.vpc.public_subnet_ids)
}



resource "kubernetes_secret" "db_credentials" {
  count = var.enable_k8s ? 1 : 0

  metadata {
    name      = "db-credentials"
    namespace = "ecommerce"
  }

  type = "Opaque"

  data = {
    username = base64encode(try(local.db_secret.username, "postgres"))
    password = base64encode(try(local.db_secret.password, "postgres"))
    dbname   = base64encode(try(local.db_secret.dbname, "postgres"))
    # If your RDS module output is "endpoint" use that; some modules call it "address"
    host     = base64encode(try(module.rds.endpoint, module.rds.address))
    port     = base64encode("5432")
  }

  depends_on = [kubernetes_namespace.ecommerce]
}


# NGINX Deployment
resource "kubernetes_manifest" "nginx_deploy" {
 count = (var.enable_k8s && !var.use_helm_app) ? 1 : 0

  depends_on = [kubernetes_namespace.ecommerce]
  manifest = {
    "apiVersion" = "apps/v1"
    "kind"       = "Deployment"
    "metadata"   = { "name" = "nginx", "namespace" = "ecommerce" }
    "spec" = {
      "replicas" = 1
      "selector" = { "matchLabels" = { "app" = "nginx" } }
      "template" = {
        "metadata" = { "labels" = { "app" = "nginx" } }
        "spec" = {
          "containers" = [{
            "name"  = "nginx"
            "image" = "nginx:1.25-alpine"
            "ports" = [{ "containerPort" = 80 }]
          }]
        }
      }
    }
  }
}

# ClusterIP Service
resource "kubernetes_manifest" "nginx_svc" {
 count = (var.enable_k8s && !var.use_helm_app) ? 1 : 0

  depends_on = [kubernetes_manifest.nginx_deploy]

  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Service"
    "metadata"   = { "name" = "nginx", "namespace" = "ecommerce" }
    "spec" = {
      "selector" = { "app" = "nginx" }
      "ports"    = [{ "port" = 80, "targetPort" = 80, "protocol" = "TCP" }]
      "type"     = "ClusterIP"
    }
  }
}


# --- IRSA for AWS Load Balancer Controller ---

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# If your EKS module exposes these, great; otherwise use data sources like you've done.
# We assume module.eks.cluster_oidc_issuer_url and module.eks.oidc_provider_arn are available.

resource "aws_iam_role" "alb_controller" {
  name = "${module.eks.cluster_name}-alb-controller"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = module.eks.oidc_provider_arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          # OIDC issuer hostpath: e.g., oidc.eks.us-east-1.amazonaws.com/id/XXXX
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com",
          "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# DEV-ONLY: broad but unblocks the controller fast
resource "aws_iam_role_policy_attachment" "alb_elb_full" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_iam_role_policy_attachment" "alb_ec2_full" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "alb_iam_read" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}


resource "kubernetes_manifest" "nginx_ingress" {
  count      = var.enable_k8s ? 1 : 0
  depends_on = [helm_release.aws_load_balancer_controller, kubernetes_manifest.nginx_svc]

  manifest = {
    "apiVersion" = "networking.k8s.io/v1"
    "kind"       = "Ingress"
    "metadata" = {
      "name"      = "nginx"
      "namespace" = "ecommerce"
      "annotations" = {
        "kubernetes.io/ingress.class"                = "alb"
        "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"      = "ip"
        "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80}]"
        "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      }
    }
    "spec" = {
      "rules" = [{
        "http" = {
          "paths" = [{
            "path"     = "/"
            "pathType" = "Prefix"
            "backend"  = {
              "service" = { "name" = "wordpress", "port" = { "number" = 80 } }
            }
          }]
        }
      }]
    }
  }
}
