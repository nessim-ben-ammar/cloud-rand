# Cloud Rand

This project deploys a serverless API that returns verifiable random numbers. It
uses AWS Lambda, API Gateway, DynamoDB and KMS managed through Terraform.

## Naming conventions

 - **Terraform identifiers** (resource and module names) use underscores (`_`)
   to comply with Terraform's naming rules.
- **AWS resource names** are based on the pattern
  `<project>-<environment>-<component>`. The `project` and `environment` values
  come from the `project_name` and `environment` variables. This ensures that
  development and production resources remain isolated while keeping a clear and
  consistent naming scheme.

For example, when `project_name` is `cloud-rand` and `environment` is `dev`, the
Lambda function handling integers will be named `cloud-rand-dev-int`. The
associated API Gateway will be named `cloud-rand-dev-api`.
