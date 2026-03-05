terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  # Uncomment after creating the S3 bucket manually:
  # aws s3 mb s3://viwell-terraform-state-frankfurt --region eu-central-1 --profile viwell-v2-staging
  # backend "s3" {
  #   bucket  = "viwell-terraform-state-frankfurt"
  #   key     = "staging/terraform.tfstate"
  #   region  = "eu-central-1"
  #   profile = "viwell-v2-staging"
  #   encrypt = true
  # }
}

# AWS SSO — uses your existing viwell-v2-staging profile
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment  = var.environment
      ManagedBy    = "terraform"
      Project      = "viwell"
      MigratedFrom = "me-central-1"
    }
  }
}

# Kubernetes provider — configured after EKS is created
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region, "--profile", var.aws_profile]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region, "--profile", var.aws_profile]
    }
  }
}
