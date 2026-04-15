locals {
    common_tags = {
        Project = "terraform-aws-ecs-fargate"
        MangedBy= "Terraform"
    }
}

/* we are creating full bootsrap from start.
state bucket will store terraform.tfstate file remotely instead of
in local machine, so a team can work on it
*/
resource "aws_s3_bucket" "state" {
  bucket = "terraform-ecs-fargate-state-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = local.common.tags

}

resource "aws_s3_bucket_versioning" "state" {
    bucket = aws_s3_bucket.state.id

    versioning_configuration {
      status = "Enabled"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {}
}

resource "aws_dynamodb_table" "lock" {
  name = "terraform-ecs-fargate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = LockID
    type = "S"
  }

  tags = local.common.tags
}
