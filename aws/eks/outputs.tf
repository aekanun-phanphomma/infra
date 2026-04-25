output "cluster_id" {
  description = "ID/name of the EKS cluster."
  value       = aws_eks_cluster.this.id
}

output "cluster_endpoint" {
  description = "API server endpoint for the EKS cluster."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the IAM OIDC provider (without https://)."
  value       = aws_iam_openid_connect_provider.eks.url
}

output "node_role_arn" {
  description = "ARN of the IAM role attached to the managed node group."
  value       = aws_iam_role.node_group.arn
}
