output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "ID of the security group attached to the instance."
  value       = aws_security_group.ec2.id
}

output "ami_id" {
  description = "ID of the Amazon Linux 2023 AMI used for the instance."
  value       = data.aws_ami.amazon_linux_2023.id
}
