terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.50" }
    helm = { source = "hashicorp/helm", version = "~> 2.13" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.31" }
  }
}
