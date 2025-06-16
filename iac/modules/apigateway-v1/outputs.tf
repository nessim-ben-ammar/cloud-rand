output "rest_api_id" {
  value       = aws_api_gateway_rest_api.this.id
  description = "The ID of the API Gateway REST API"
}

output "rest_api_root_resource_id" {
  value       = aws_api_gateway_rest_api.this.root_resource_id
  description = "The root resource ID of the API Gateway"
}

output "rest_api_execution_arn" {
  value       = aws_api_gateway_rest_api.this.execution_arn
  description = "The execution ARN of the API Gateway"
}