variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

# OIDC provider ARN for the EKS cluster (from your EKS module)
variable "cluster_oidc_arn" {
  type = string
}

# OIDC issuer URL for the EKS cluster, e.g. "https://oidc.eks.us-east-1.amazonaws.com/id/XXXX"
# (Add this output in your EKS module if you don't have it yet; see note below.)
variable "cluster_oidc_url" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "domain_suffix" {
  type = string
}

# Secrets ARNs that external-secrets may read. Use explicit ARNs when possible.
variable "external_secrets_secret_arns" {
  type    = list(string)
  default = []
}

variable "enable_external_dns" {
  type    = bool
  default = false
}

variable "enable_tls" {
  type    = bool
  default = false
}
