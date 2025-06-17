resource "aws_api_gateway_rest_api" "this" {
  name        = var.apigw-config.name
  description = var.apigw-config.description
}

resource "aws_api_gateway_resource" "this" {
  for_each    = { for idx, ep in var.apigw-config.endpoints : idx => ep }
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.path
}

resource "aws_api_gateway_method" "this" {
  for_each      = { for idx, ep in var.apigw-config.endpoints : idx => ep }
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this[each.key].id
  http_method   = each.value.method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "this" {
  for_each                = { for idx, ep in var.apigw-config.endpoints : idx => ep }
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this[each.key].id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.uri
}


resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    aws_api_gateway_integration.this
  ]
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    redeploy = sha1(jsonencode(var.apigw-config.endpoints))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.apigw-config.stage
  description   = "Stage for ${var.apigw-config.name} API"
}

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.apigw-config.rate_limit
    throttling_burst_limit = var.apigw-config.burst_limit
  }

}
