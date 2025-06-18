resource "aws_api_gateway_rest_api" "api" {
  name        = local.apigw_config.name
  description = local.apigw_config.description
}

resource "aws_api_gateway_resource" "endpoint" {
  for_each    = { for idx, ep in local.apigw_config.endpoints : idx => ep }
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.value.path
}

resource "aws_api_gateway_method" "endpoint" {
  for_each      = { for idx, ep in local.apigw_config.endpoints : idx => ep }
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.endpoint[each.key].id
  http_method   = each.value.method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "endpoint" {
  for_each                = { for idx, ep in local.apigw_config.endpoints : idx => ep }
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.endpoint[each.key].id
  http_method             = aws_api_gateway_method.endpoint[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.uri
}

resource "aws_api_gateway_deployment" "api" {
  depends_on = [
    aws_api_gateway_integration.endpoint
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeploy = sha1(jsonencode(local.apigw_config.endpoints))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = local.apigw_config.stage
  description   = "Stage for ${local.apigw_config.name} API"
}

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = local.apigw_config.rate_limit
    throttling_burst_limit = local.apigw_config.burst_limit
  }

}
