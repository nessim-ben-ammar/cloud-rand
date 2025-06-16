variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  type        = string
  description = "The deployment environment (e.g., dev, prod, staging)"
  default     = "dev"
}