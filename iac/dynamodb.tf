resource "aws_dynamodb_table" "operation_records" {
  name         = "${local.name_prefix}-operation-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "record_id"

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

resource "aws_kms_key" "dynamodb_key" {
  description             = "KMS key for ${local.name_prefix} DynamoDB table"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}
