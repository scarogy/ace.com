# Cluster basics
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

# Token for providers
output "token" {
  value = data.aws_eks_cluster_auth.this.token
}

# Cluster SG id (useful for DB ingress)
output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# IRSA provider
output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.this.arn
}

# Issuer URL (needed for IRSA 'sub' condition)
output "cluster_oidc_issuer_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
