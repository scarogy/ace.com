########################################
# eks-addons: External Secrets (IRSA inline)
########################################
# IRSA role
# resource "aws_iam_role" "external_secrets_irsa" {
#   count              = var.enable_external_secrets ? 1 : 0
#   name               = "${var.name}-external-secrets"
#   assume_role_policy = data.aws_iam_policy_document.es_assume.json
#   description        = "IRSA for External Secrets"
# }

# resource "aws_iam_policy" "external_secrets" {
#   count  = var.enable_external_secrets ? 1 : 0
#   name   = "${var.name}-external-secrets"
#   policy = data.aws_iam_policy_document.es_policy.json
# }

# resource "aws_iam_role_policy_attachment" "es_attach" {
#   count      = var.enable_external_secrets ? 1 : 0
#   role       = aws_iam_role.external_secrets_irsa[0].name
#   policy_arn = aws_iam_policy.external_secrets[0].arn
# }

# resource "helm_release" "external_secrets" {
#   count            = var.enable_external_secrets ? 1 : 0
#   name             = "external-secrets"
#   repository       = "https://charts.external-secrets.io"
#   chart            = "external-secrets"
#   namespace        = "ecommerce"
#   create_namespace = true
#   wait             = true
#   timeout          = 600

#   values = [yamlencode({
#     installCRDs = true
#     serviceAccount = {
#       create = true
#       name   = "external-secrets"
#       annotations = {
#         "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets_irsa[0].arn
#       }
#     }
#   })]
# }
