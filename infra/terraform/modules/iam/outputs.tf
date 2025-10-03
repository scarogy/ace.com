output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "gha_role_arn" {
  value = aws_iam_role.gha.arn
}

output "github_access_key_id" {
  value     = aws_iam_access_key.github_actions.id
  sensitive = true
}

output "github_secret_access_key" {
  value     = aws_iam_access_key.github_actions.secret
  sensitive = true
}