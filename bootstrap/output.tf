output "state_bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "aws_dynamodb_table" {
  value = aws_dynamodb_table.lock.name
}