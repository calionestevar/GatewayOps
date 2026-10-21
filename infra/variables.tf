# variables.tf
# DHD (Dial Home Device) - all series. The DHD controls where the
# connection goes; these variables control where Terraform dials.

variable "aws_region" {
  description = "AWS region for Gateway Ops infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application identifier used across resource names"
  type        = string
  default     = "gateway-ops"
}

variable "cluster_name" {
  description = "Name of the EKS cluster (the Gate itself)"
  type        = string
  default     = "gateway-ops-gate"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cost_tag" {
  description = "Billing tag applied to all resources for cost attribution"
  type        = string
  default     = "gateway-ops"
}