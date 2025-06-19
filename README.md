# Cloud Rand

Cloud Rand provides a small serverless API for generating cryptographically secure random values.  The service runs entirely on AWS and records every request so that results can be verified later.

## Repository overview

- **lambda/** – Python code for the three Lambda functions
- **iac/** – Terraform configuration that deploys the API Gateway, Lambda functions, DynamoDB table and supporting infrastructure
- **test/** – simple script that demonstrates how to call the API

## Development environment

The repository includes a [dev container](.devcontainer) for a consistent setup.
You just need Docker installed on your machine to use it. The included Dockerfile
preinstalls Python 3.12 and Terraform 1.12.2, but you can modify it if you need
additional tools. Before starting the container, copy `.devcontainer/.env.example`
to `.devcontainer/.env` and fill in your AWS credentials:

```bash
cp .devcontainer/.env.example .devcontainer/.env
```

```
AWS_ACCESS_KEY_ID=<your access key>
AWS_SECRET_ACCESS_KEY=<your secret key>
AWS_DEFAULT_REGION=<aws region>
```

## Deploying your own instance

1. Start the repository in the dev container (Terraform is already installed) and make sure your AWS credentials are configured.
2. Optionally edit `iac/terraform.tfvars` to change the region, project name or environment.
3. Deploy the infrastructure:

   ```bash
   cd iac
   terraform init
   terraform apply
   ```

   After the apply completes, Terraform prints the API identifier.  The base URL for requests is:

   ```
   https://<rest_api_id>.execute-api.<region>.amazonaws.com/v1
   ```

   You can output the API ID again at any time with `terraform output rest_api_id`.

## Using the API

All endpoints accept and return JSON.  Examples below assume `BASE_URL` is set to the URL shown after deployment.

### `POST /hex`
Generate one or more random hexadecimal strings.

```bash
curl -X POST "$BASE_URL/hex" \
     -H 'Content-Type: application/json' \
     -d '{"length": 4, "count": 2}'
```

Response:

```json
{
  "record_id": "<uuid>",
  "values": ["d93f", "8a21"]
}
```

### `POST /int`
Generate random integers within a range.

```bash
curl -X POST "$BASE_URL/int" \
     -H 'Content-Type: application/json' \
     -d '{"range_min": 1, "range_max": 100, "count": 3}'
```

### `GET /verify?record_id=<id>`
Retrieve the complete record for a previous request, including the seed used to generate the values.

```bash
curl "$BASE_URL/verify?record_id=<id>"
```

The response echoes the original request parameters, the generated values and the hex-encoded seed stored in DynamoDB.

## License

This project is released under the MIT License.  See the [LICENSE](LICENSE) file for details.
