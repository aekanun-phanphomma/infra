# aws/s3

Deploys a secure, production-ready S3 bucket with:
- Versioning enabled
- SSE-KMS encryption (customer-managed or AWS-managed key)
- All public access blocked
- Lifecycle rules: transition to STANDARD_IA at 90 days, GLACIER at 365 days, and noncurrent version expiration at 90 days
- Optional server access logging to a separate bucket

## Usage

```hcl
module "s3" {
  source = "./infra/aws/s3"

  aws_region        = "us-east-1"
  bucket_name       = "my-company-data-prod-20240101"
  kms_key_id        = "arn:aws:kms:us-east-1:123456789012:key/abc-123"
  access_log_bucket = "my-company-access-logs"

  tags = {
    environment = "production"
    team        = "data"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| aws_region | string | `"us-east-1"` | AWS region to deploy resources into. |
| bucket_name | string | *(required)* | Globally unique S3 bucket name. |
| kms_key_id | string | `""` | KMS key ID or ARN for SSE-KMS encryption. Uses the AWS-managed S3 key if left empty. |
| access_log_bucket | string | `""` | Name of an existing S3 bucket to receive server access logs. Leave empty to disable logging. |
| tags | map(string) | `{}` | Map of tags to apply to all resources. |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | Name/ID of the S3 bucket. |
| bucket_arn | ARN of the S3 bucket. |
| bucket_domain_name | Bucket-style domain name of the S3 bucket. |
