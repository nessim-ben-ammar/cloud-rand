locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "apigateway-v1" {
  source = "./modules/apigateway-v1"
  apigw_config = {
    name        = "${local.name_prefix}-api"
    description = "API to serve verfiable random numbers"
    stage       = "v1"
    rate_limit  = 100
    burst_limit = 100
    endpoints = [
      {
        path   = "int"
        method = "POST"
        uri    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud-rand-int.lambda_function_arn}/invocations"
      },
      {
        path   = "hex"
        method = "POST"
        uri    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud-rand-hex.lambda_function_arn}/invocations"
      },
      {
        path   = "verify"
        method = "GET"
        uri    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud-rand-verify.lambda_function_arn}/invocations"
      }
    ]
  }
}

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

module "cloud-rand-int" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.21.0"

  function_name  = "${local.name_prefix}-int"
  handler        = "int.handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  attach_policy  = true
  policy         = aws_iam_policy.service_access.arn
  publish        = true
  create_package = false

  local_existing_package = data.archive_file.lambda_zip.output_path

  cloudwatch_logs_retention_in_days = 7

  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.operation_records.name
  }
}

module "cloud-rand-hex" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.21.0"

  function_name  = "${local.name_prefix}-hex"
  handler        = "hex.handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  attach_policy  = true
  policy         = aws_iam_policy.service_access.arn
  publish        = true
  create_package = false

  local_existing_package = data.archive_file.lambda_zip.output_path

  cloudwatch_logs_retention_in_days = 7

  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.operation_records.name
  }
}

module "cloud-rand-verify" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.21.0"

  function_name  = "${local.name_prefix}-verify"
  handler        = "verify.handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  attach_policy  = true
  policy         = aws_iam_policy.service_access.arn
  publish        = true
  create_package = false

  local_existing_package = data.archive_file.lambda_zip.output_path

  cloudwatch_logs_retention_in_days = 7

  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.operation_records.name
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

resource "aws_lambda_permission" "verify_api_gw" {
  statement_id  = "AllowExecutionFromAPIGatewayVerify"
  action        = "lambda:InvokeFunction"
  function_name = module.cloud-rand-verify.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.apigateway-v1.rest_api_execution_arn}/*/*"
}

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

resource "aws_wafv2_web_acl" "api_gw_waf" {
  name        = "${local.name_prefix}-waf"
  description = "WAF with rate limiting"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${local.name_prefix}-waf"
  }

  rule {
    name     = "${local.name_prefix}-waf-ip-rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 10
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-waf-ip-rate-limit"
    }
  }

  rule {
    name     = "${local.name_prefix}-waf-body-size-restriction"
    priority = 2

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        comparison_operator = "GT"
        size                = 256
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-waf-body-size-restriction"
    }
  }

  rule {
    name     = "${local.name_prefix}-waf-core-rule-set"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-waf-core-rule-set"
    }
  }
}

resource "aws_wafv2_web_acl_association" "api_gw_waf" {
  resource_arn = module.apigateway-v1.rest_api_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.api_gw_waf.arn
}
