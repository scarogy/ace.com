# Fetch the cert chain for GitHub's OIDC issuer so we can derive a current thumbprint
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]

  # Use the leaf certificate SHA1 thumbprint from the fetched chain
  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]
}

# Trust policy allowing GitHub Actions (OIDC) from a specific repo + ref
data "aws_iam_policy_document" "gha_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Limit to your repository and the main branch refs/heads/main
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gha" {
  name               = "${var.name}-gha"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_role.json
  description        = "GitHub Actions role for ${var.github_org}/${var.github_repo} (main branch)"
  force_detach_policies = true
}

# Simple broad policy for bootstrapping; tighten later to least-privilege
data "aws_iam_policy_document" "gha_inline" {
  statement {
    sid     = "AllowTerraformBootstrap"
    effect  = "Allow"
    actions = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "gha" {
  name        = "${var.name}-gha-inline"
  description = "Bootstrap permissions for Terraform via GitHub Actions"
  policy      = data.aws_iam_policy_document.gha_inline.json
}

resource "aws_iam_role_policy_attachment" "gha_attach" {
  role       = aws_iam_role.gha.name
  policy_arn = aws_iam_policy.gha.arn
}
