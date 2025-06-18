output "rest_api_id" {
  value       = module.apigateway-v1.rest_api_id
  description = "The ID of the API Gateway REST API"
}

output "rest_api_root_resource_id" {
  value       = module.apigateway-v1.rest_api_root_resource_id
  description = "The root resource ID of the API Gateway"
}

output "rest_api_execution_arn" {
  value       = module.apigateway-v1.rest_api_execution_arn
  description = "The execution ARN of the API Gateway"
}

