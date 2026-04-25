# aws/ec2

Deploys a single Amazon Linux 2023 EC2 instance with:
- Latest AL2023 AMI (auto-resolved via data source)
- Encrypted gp3 root volume
- IMDSv2 enforced (token-required metadata)
- Dedicated security group with configurable ingress rules
- Optional IAM instance profile attachment

## Usage

```hcl
module "ec2" {
  source = "./infra/aws/ec2"

  aws_region    = "us-east-1"
  instance_name = "ec2-app-01"
  instance_type = "t3.medium"
  vpc_id        = "vpc-0abc123456"
  subnet_id     = "subnet-0abc123456"
  key_pair_name = "my-key-pair"

  root_volume_size_gb  = 50
  iam_instance_profile = "ec2-ssm-role"

  ingress_rules = [
    {
      description = "Allow HTTPS from VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]

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
| instance_name | string | `"ec2-app-01"` | Name tag for the EC2 instance and related resources. |
| instance_type | string | `"t3.medium"` | EC2 instance type. |
| vpc_id | string | *(required)* | VPC ID where the security group will be created. |
| subnet_id | string | *(required)* | Subnet ID in which to launch the EC2 instance. |
| key_pair_name | string | *(required)* | Name of an existing EC2 key pair for SSH access. |
| iam_instance_profile | string | `null` | IAM instance profile name to attach to the instance. |
| root_volume_size_gb | number | `50` | Size of the root EBS volume in GB. |
| ingress_rules | list(object) | `[]` | List of ingress rules for the security group. |
| tags | map(string) | `{}` | Map of tags to apply to all resources. |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | ID of the EC2 instance. |
| private_ip | Private IP address of the EC2 instance. |
| security_group_id | ID of the security group attached to the instance. |
| ami_id | ID of the Amazon Linux 2023 AMI used for the instance. |
