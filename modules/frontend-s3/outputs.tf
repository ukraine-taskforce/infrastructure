output "s3_bucket_name" {
  description = "The name of the bucket."
  value = module.frontend.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "The ARN of the bucket. Will be of format arn:aws:s3:::bucketname."
  value       = module.frontend.s3_bucket_arn
}
