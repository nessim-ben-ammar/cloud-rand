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
  type                    = each.value.integration_type
  uri                     = each.value.uri

  credentials       = each.value.integration_type == "AWS" ? var.apigw-config.role_arn : null
  request_templates = try(each.value.request_templates, null)
}

locals {
  verify_key    = [for k, ep in var.apigw-config.endpoints : k if ep.path == "verify" && ep.method == "GET"][0]
  verify_is_aws = try(var.apigw-config.endpoints[local.verify_key].integration_type == "AWS", false)
}

resource "aws_api_gateway_integration_response" "verify_get_200" {
  count       = local.verify_is_aws ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[local.verify_key].id
  http_method = aws_api_gateway_method.this[local.verify_key].http_method
  status_code = "200"
  response_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
#if($inputRoot.Item)
$input.json('$.Item')
#else
{
  "Item": null,
  "message": "Item not found"
}
#end
EOF
  }
}

resource "aws_api_gateway_method_response" "verify_get_200" {
  count       = local.verify_is_aws ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[local.verify_key].id
  http_method = aws_api_gateway_method.this[local.verify_key].http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
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
