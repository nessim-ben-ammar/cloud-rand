module "cloud_rand_int" {
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

module "cloud_rand_hex" {
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

module "cloud_rand_verify" {
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
