variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance and related resources."
  type        = string
  default     = "ec2-app-01"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID in which to launch the EC2 instance."
  type        = string
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to the instance."
  type        = string
  default     = null
}

variable "root_volume_size_gb" {
  description = "Size of the root EBS volume in GB."
  type        = number
  default     = 50
}

variable "ingress_rules" {
  description = "List of ingress rules for the security group."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
