# main.tf
# The Gate: EKS with Fargate profiles.
#
# STATE OF PLAY: local development runs against a Kind cluster (see README),
# which Terraform does not manage. This configuration defines the AWS target
# the same K8s manifests deploy against - see INFRASTRUCTURE_MIGRATION.md.
# The iris-validation.sh gate runs fmt/validate against these files on every
# push regardless of backend, so this config is continuously checked even
# before the first cloud apply.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  # Backend intentionally UNDEFINED for local validation.
  # The S3 backend is applied during cloud migration (INFRASTRUCTURE_MIGRATION.md)
  # via: terraform init -migrate-state
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project = var.cost_tag
      Managed = "terraform"
    }
  }
}

locals {
  # Atlantis (the city) = the local dev environment per the naming schema.
  # Prod resources dial out from here.
  name_prefix = var.app_name
}

# --- VPC module: the dialing plane ---
module "vpc" {
  source = "./modules/vpc"

  name_prefix = local.name_prefix
  cidr_block  = var.vpc_cidr
  azs         = ["${var.aws_region}a", "${var.aws_region}b"]

  tags = { Project = var.cost_tag }
}

# --- EKS control plane: the Gate itself ---
resource "aws_eks_cluster" "gate" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = module.vpc.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["10.0.0.0/8", "172.16.0.0/12"]  # Private ranges only
  }
  
  encryption_config {
    resources = ["secrets"]
    provider {
      key = aws_kms_key.eks_secrets.arn
    }
  }
  
  logging {
    cluster_logging {
      enabled_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    }
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_kms_key" "eks_secrets" {
  description             = "EKS cluster secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# --- Fargate profile: travel without managing nodes ---
resource "aws_eks_fargate_profile" "traveler" {
  cluster_name           = aws_eks_cluster.gate.name
  fargate_profile_name   = "traveler-${var.app_name}"
  pod_execution_role_arn = aws_iam_role.fargate_traveler.arn
  subnet_ids             = module.vpc.private_subnet_ids

  # The sgc namespace from k8s/sgc-namespace.yaml
  selector {
    namespace = "sgc"
  }
}

# --- IAM: who may travel ---
resource "aws_iam_role" "eks_cluster" {
  name = "${local.name_prefix}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "fargate_traveler" {
  name = "${local.name_prefix}-fargate-traveler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks-fargate-pods.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_traveler_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_traveler.name
}