module "apigateway-v1" {
  source = "./modules/apigateway-v1"
  apigw-config = {
    name        = "cloud-rand"
    description = "API to serve verfiable random numbers"
    stage       = "v1"
    rate_limit  = 100
    burst_limit = 100
    role_arn    = aws_iam_role.apigw_dynamodb_role.arn
    endpoints = [
      {
        path             = "int"
        method           = "POST"
        integration_type = "AWS_PROXY"
        uri              = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud-rand-int.lambda_function_arn}/invocations"
      },
      {
        path             = "hex"
        method           = "POST"
        integration_type = "AWS_PROXY"
        uri              = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud-rand-hex.lambda_function_arn}/invocations"
      },
      {
        path             = "verify"
        method           = "GET"
        integration_type = "AWS"
        uri              = "arn:aws:apigateway:${var.region}:dynamodb:action/GetItem"
        request_templates = {
          "application/json" = <<EOF
{
  "TableName": "cloud-rand-prod-operation-records",
  "Key": {
    "record_id": { "S": "$input.params('record_id')" }
  }
}
EOF
        }
      }
    ]
  }
}

resource "aws_dynamodb_table" "cloud-rand-prod-operation-records" {
  name         = "cloud-rand-prod-operation-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "record_id"

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.cloud-rand-prod-dynamodb-key.arn
  }

  attribute {
    name = "record_id"
    type = "S"
  }

  tags = {
    project     = "cloud-rand"
    environment = "prod"
  }
}

resource "aws_kms_key" "cloud-rand-prod-dynamodb-key" {
  description             = "KMS key for cloud-rand-prod DynamoDB table"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

module "cloud-rand-int" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.21.0"

  function_name  = "cloud-rand-prod-int"
  handler        = "int.handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  attach_policy  = true
  policy         = aws_iam_policy.cloud-rand-prod-service-access.arn
  publish        = true
  create_package = false

  local_existing_package = data.archive_file.lambda_zip.output_path

  cloudwatch_logs_retention_in_days = 7

  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.cloud-rand-prod-operation-records.name
  }
}

module "cloud-rand-hex" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.21.0"

  function_name  = "cloud-rand-prod-hex"
  handler        = "hex.handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  attach_policy  = true
  policy         = aws_iam_policy.cloud-rand-prod-service-access.arn
  publish        = true
  create_package = false

  local_existing_package = data.archive_file.lambda_zip.output_path

  cloudwatch_logs_retention_in_days = 7

  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.cloud-rand-prod-operation-records.name
  }
}

resource "aws_lambda_permission" "int_api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.cloud-rand-int.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.apigateway-v1.rest_api_execution_arn}/*/*"
}

resource "aws_lambda_permission" "hex_api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.cloud-rand-hex.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.apigateway-v1.rest_api_execution_arn}/*/*"
}

resource "aws_iam_policy" "cloud-rand-prod-service-access" {
  name        = "cloud-rand-prod-service-access"
  description = "Policy to allow grant cloud-rand-prod the necessary access"
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
        Resource = aws_kms_key.cloud-rand-prod-dynamodb-key.arn
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
        Resource = aws_dynamodb_table.cloud-rand-prod-operation-records.arn
      }
    ]
  })
}

resource "aws_iam_role" "apigw_dynamodb_role" {
  name = "apigw-dynamodb-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apigw_dynamodb_access" {
  name = "apigw-dynamodb-read"
  role = aws_iam_role.apigw_dynamodb_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      Resource = aws_dynamodb_table.cloud-rand-prod-operation-records.arn
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.cloud-rand-prod-dynamodb-key.arn
      }
    ]
  })
}
