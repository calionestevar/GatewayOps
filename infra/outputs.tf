# outputs.tf

output "cluster_name" {
  description = "Name of the EKS cluster (the Gate)"
  value       = aws_eks_cluster.gate.name
}

output "cluster_endpoint" {
  description = "API endpoint for the Gate"
  value       = aws_eks_cluster.gate.endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64) - needed for kubeconfig"
  value       = aws_eks_cluster.gate.certificate_authority[0].data
  sensitive   = true
}

output "configure_kubectl_command" {
  description = "Run this to point kubectl at the cloud Gate"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.gate.name} --region ${var.aws_region}"
}