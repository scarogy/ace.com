bucket         = "tfstate-ace"
key            = "eks-baseline/stg/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "tfstate-locks"
encrypt        = true
