module "apigateway-v1" {
  source = "./modules/apigateway-v1"
  apigw-config = {
    name        = "cloud-rand"
    description = "API to serve verfiable random numbers"
    stage       = "v1"
    rate_limit  = 100
    burst_limit = 100
    endpoints = [
      {
        path   = "int"
        method = "POST"
        uri    = module.cloud-rand-int.lambda_function_arn
      },
      {
        path   = "hex"
        method = "POST"
        uri    = module.cloud-rand-hex.lambda_function_arn
      }
    ]
  }
}

module "cloud-rand-int" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.21.0"

  function_name  = "cloud-rand-prod-int"
  handler        = "int.handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  publish        = true
  create_package = false

  local_existing_package = data.archive_file.int_lambda_zip.output_path

  cloudwatch_logs_retention_in_days = 7

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.apigateway-v1.rest_api_execution_arn}/*/*"
    }
  }
}

module "cloud-rand-hex" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.21.0"

  function_name  = "cloud-rand-prod-hex"
  handler        = "hex.handler"
  runtime        = "python3.12"
  architectures  = ["arm64"]
  publish        = true
  create_package = false

  local_existing_package = data.archive_file.int_lambda_zip.output_path

  cloudwatch_logs_retention_in_days = 7

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.apigateway-v1.rest_api_execution_arn}/*/*"
    }
  }
}
