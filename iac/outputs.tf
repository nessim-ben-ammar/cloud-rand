output "rest_api_id" {
  value       = aws_api_gateway_rest_api.api.id
  description = "The ID of the API Gateway REST API"
}
