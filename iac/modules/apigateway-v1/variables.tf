variable "apigw_config" {
  description = "API Gateway configuration"
  type = object({
    name        = string
    description = string
    stage       = string
    rate_limit  = optional(number, 10000)
    burst_limit = optional(number, 5000)
    endpoints = list(object({
      path   = string
      method = string
      uri    = string
    }))
  })
}
