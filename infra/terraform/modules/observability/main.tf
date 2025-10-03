data "aws_region" "current" {}
resource "aws_cloudwatch_log_group" "pods" {
  name              = "/eks/${var.name}/pods"
  retention_in_days = 30
}
resource "aws_sns_topic" "ops" { name = "${var.name}-ops" }
resource "helm_release" "fluentbit" {
  name             = "aws-for-fluent-bit"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-for-fluent-bit"
  namespace        = "logging"
  create_namespace = true

  values = [yamlencode({
    cloudWatch = {
      enabled = true
      region  = data.aws_region.current.name
    }
  })]
}
