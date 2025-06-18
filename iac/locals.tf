locals {
  name_prefix = "${var.project_name}-${var.environment}"
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
        uri    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud_rand_int.lambda_function_arn}/invocations"
      },
      {
        path   = "hex"
        method = "POST"
        uri    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud_rand_hex.lambda_function_arn}/invocations"
      },
      {
        path   = "verify"
        method = "GET"
        uri    = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${module.cloud_rand_verify.lambda_function_arn}/invocations"
      }
    ]
  }
}

