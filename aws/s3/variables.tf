variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID or ARN for SSE-KMS encryption. Uses the AWS-managed S3 key if left empty."
  type        = string
  default     = ""
}

variable "access_log_bucket" {
  description = "Name of an existing S3 bucket to receive server access logs. Leave empty to disable logging."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
