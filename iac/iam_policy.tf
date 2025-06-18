resource "aws_iam_policy" "service_access" {
  name        = "${local.name_prefix}-service-access"
  description = "Policy to allow ${local.name_prefix} the necessary access"
  lifecycle {
    create_before_destroy = false
  }
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "kms:GenerateRandom",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.dynamodb_key.arn
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.operation_records.arn
      }
    ]
  })
}
