provider "aws" {
  region = var.region
}



resource "aws_s3_bucket" "terraform_state" {
  bucket = "ilyas-tfstate"

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Name        = "states bucket for Telegram bot"
    Environment = "Dev"
  }
}

# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_dynamodb_table" "terraform_state_lock" {
#   name           = "state"
#   read_capacity  = 1
#   write_capacity = 1
#   hash_key       = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }
