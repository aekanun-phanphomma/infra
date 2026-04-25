# aws/eks

Deploys a private Amazon EKS cluster with:
- Private-only API server endpoint (no public access)
- Full control plane logging (API, audit, authenticator, controller manager, scheduler)
- IAM OIDC provider for IRSA (IAM Roles for Service Accounts)
- Managed node group with ON_DEMAND instances and rolling update support
- Least-privilege IAM roles for the cluster and node group
- Partition-aware IAM policy ARNs (supports GovCloud and China regions)

## Usage

```hcl
module "eks" {
  source = "./infra/aws/eks"

  aws_region         = "us-east-1"
  cluster_name       = "eks-prod"
  kubernetes_version = "1.29"
  vpc_id             = "vpc-0abc123456"
  subnet_ids         = ["subnet-0aaa", "subnet-0bbb", "subnet-0ccc"]

  node_instance_types = ["m5.xlarge"]
  node_desired_count  = 3
  node_min_count      = 2
  node_max_count      = 10

  tags = {
    environment = "production"
    team        = "platform"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| aws_region | string | `"us-east-1"` | AWS region to deploy resources into. |
| cluster_name | string | `"eks-prod"` | Name of the EKS cluster. |
| kubernetes_version | string | `"1.29"` | Kubernetes version for the EKS cluster. |
| vpc_id | string | *(required)* | VPC ID for the EKS cluster control plane security group. |
| subnet_ids | list(string) | *(required)* | Private subnet IDs for EKS nodes and control plane ENIs. |
| node_instance_types | list(string) | `["m5.xlarge"]` | List of EC2 instance types for the managed node group. |
| node_desired_count | number | `3` | Desired number of worker nodes. |
| node_min_count | number | `2` | Minimum number of worker nodes. |
| node_max_count | number | `10` | Maximum number of worker nodes. |
| tags | map(string) | `{}` | Map of tags to apply to all resources. |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ID/name of the EKS cluster. |
| cluster_endpoint | API server endpoint for the EKS cluster. |
| cluster_certificate_authority | Base64-encoded certificate authority data for the cluster. |
| oidc_provider_arn | ARN of the IAM OIDC provider for IRSA. |
| oidc_provider_url | URL of the IAM OIDC provider (without https://). |
| node_role_arn | ARN of the IAM role attached to the managed node group. |
