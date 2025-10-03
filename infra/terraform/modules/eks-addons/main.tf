########################################
# eks-addons: ALB Controller + external-dns (IRSA inline)
########################################

locals {
  # issuer host/path for IRSA conditions (remove "https://")
  oidc_issuer_hostpath = replace(var.cluster_oidc_url, "https://", "")
}

data "aws_region" "current" {}

########################################
# ALB Controller IRSA
########################################
# -----------------------------
# external-dns IRSA policies
# -----------------------------

# Assume-role policy for the SA kube-system:external-dns
data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.cluster_oidc_arn]
    }

    # OIDC audience must be sts.amazonaws.com
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Bind specifically to the external-dns service account
    condition {
      test     = "StringLike"
      variable = "${local.oidc_issuer_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }
  }
}

# Minimal Route 53 permissions for external-dns
data "aws_iam_policy_document" "external_dns_policy" {
  statement {
    sid     = "ChangeRecords"
    effect  = "Allow"
    actions = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/*"]  # tighten to specific zone ARNs later
  }
  statement {
    sid     = "ListZones"
    effect  = "Allow"
    actions = ["route53:ListHostedZones","route53:ListResourceRecordSets"]
    resources = ["*"]
  }
}
