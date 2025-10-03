# ACE.com - Production-Ready AWS Infrastructure

A comprehensive, production-ready infrastructure-as-code solution for deploying scalable applications on AWS with Kubernetes (EKS), complete observability, and automated CI/CD pipelines.

Overview

ACE.com provides a complete infrastructure stack that includes:
- **Container Orchestration**: Amazon EKS (Elastic Kubernetes Service) with IRSA (IAM Roles for Service Accounts)
- **Networking**: VPC with proper security and isolation
- **Load Balancing**: AWS Application Load Balancer (ALB) with automatic DNS management
- **Database**: RDS PostgreSQL with encryption, automated backups, and secret management
- **Security**: TLS/SSL certificates via ACM, encrypted secrets, private subnets
- **Observability**: Fluent Bit for log aggregation and SNS for notifications
- **Multi-Environment**: Separate dev, staging, and production environments
- **CI/CD**: GitHub Actions with OIDC authentication for secure deployments

## 📋 Features

### Infrastructure Components

- **Amazon VPC**: Isolated network environment with public and private subnets
- **EKS Cluster**: Managed Kubernetes with:
  - IRSA for pod-level AWS IAM permissions
  - ALB Ingress Controller for load balancing
  - external-dns for automatic DNS record management
- **RDS PostgreSQL**: 
  - Deployed in private subnets
  - Encrypted at rest
  - Automated backups
  - Credentials managed via AWS Secrets Manager
- **External Secrets Operator**: Automatically syncs database credentials from AWS Secrets Manager to Kubernetes secrets
- **ACM Certificates**: Per-environment SSL/TLS certificates for HTTPS
- **Observability Stack**:
  - Fluent Bit for centralized logging
  - SNS for alerting and notifications

### Application Deployment

- **Helm Chart**: Pre-configured with nginx as the default application
- **HTTPS Ingress**: Automatic TLS termination and routing
- **Environment Parity**: Consistent configuration across dev/staging/prod

### State Management

- **Terraform State**: Remote state stored in S3 with DynamoDB locking
- **Bootstrap Stack**: Automated setup of state management infrastructure
- **Environment Isolation**: Separate state files per environment

### CI/CD Pipeline

- **GitHub Actions Workflows**:
  - Infrastructure planning and applying via Terraform
  - Application deployment via Helm
  - Marketplace chart packaging for distribution
- **OIDC Authentication**: Secure, keyless authentication to AWS using GitHub's OIDC provider
- **Automated Deployments**: Push-to-deploy workflow for both infrastructure and applications

## 🛠️ Prerequisites

Before you begin, ensure you have the following:

- AWS Account with appropriate permissions
- GitHub account with OIDC configured for AWS
- Terraform installed (v1.0+)
- kubectl installed
- Helm 3 installed
- AWS CLI configured


### 1. Bootstrap Remote State

First, set up the S3 bucket and DynamoDB table for Terraform state:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### 2. Configure Environment Variables

Create a `terraform.tfvars` file for each environment:

```hcl
# terraform/environments/dev/terraform.tfvars
environment = "dev"
region = "us-east-1"
cluster_name = "eks-dev"
db_instance_class = "db.t3.micro"
```


## 🔒 Security Features

- **Network Isolation**: RDS in private subnets, no public access
- **Encryption**: 
  - RDS encrypted at rest using AWS KMS
  - TLS/SSL for all external connections via ACM
- **Secret Management**: 
  - Database credentials in AWS Secrets Manager
  - Automatic rotation support
  - Kubernetes secrets via External Secrets Operator
- **IAM**: 
  - Least privilege access via IRSA
  - OIDC for GitHub Actions (no long-lived credentials)
- **Backups**: Automated RDS backups with point-in-time recovery

## 🌍 Environments

### Development
- Smaller instance sizes for cost optimization
- Relaxed security groups for easier testing
- Single AZ deployment

### Staging
- Production-like configuration
- Multi-AZ for reliability testing
- Pre-production validation

### Production
- High availability across multiple AZs
- Enhanced monitoring and alerting
- Automated backups with extended retention

## 📊 Monitoring & Observability

### Logging
- **Fluent Bit**: Collects logs from all pods and nodes
- **CloudWatch**: Centralized log storage and analysis
- **Log Streams**: Separate streams per environment and service

### Alerts
- **SNS Topics**: Environment-specific notification channels
- **CloudWatch Alarms**: 
  - Pod health checks
  - Node resource utilization
  - Database performance metrics
  - ALB health status

## 🔄 CI/CD Workflow

### Infrastructure Changes
1. Open PR with Terraform changes
2. Automated `terraform plan` runs and comments on PR
3. Review and merge PR
4. Automated `terraform apply` runs on merge to main

### Application Deployments
1. Push code changes to main branch
2. Docker image built and pushed to ECR
3. Helm chart updated with new image tag
4. Rolling deployment to EKS cluster
5. Health checks verify deployment

### Chart Distribution
- Helm charts packaged for marketplace distribution
- Automated versioning and release notes
- Published to Helm repository
