variable "apigw-config" {
  description = "API Gateway configuration"
  type = object({
    name        = string
    description = string
    stage       = string
    rate_limit  = optional(number, 10000)
    burst_limit = optional(number, 5000)
    role_arn    = string
    endpoints = list(object({
      path              = string
      method            = string
      uri               = string
      integration_type  = string
      request_templates = optional(map(string))
    }))
  })
}
