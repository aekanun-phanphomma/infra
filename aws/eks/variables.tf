variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "eks-prod"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster control plane security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for EKS nodes and control plane ENIs."
  type        = list(string)
}

variable "node_instance_types" {
  description = "List of EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["m5.xlarge"]
}

variable "node_desired_count" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 3
}

variable "node_min_count" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
