import boto3
import datetime
import json
import os
import uuid
from botocore.exceptions import BotoCoreError, ClientError

# Constants
MAX_COUNT = 1024
MAX_BYTES_TOTAL = 1024


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    """
    Lambda handler to generate verifiable random hex strings using AWS KMS.

    Request body JSON:
    {
        "length": int,
        "count": int (default=1)
    }

    Returns:
    {
        "record_id": UUID,
        "values": List[str]
    }
    """
    try:
        request_data = json.loads(event.get("body", "{}"))

        try:
            bytes_per_value = int(request_data["length"])
            count = int(request_data.get("count", 1))
        except (KeyError, ValueError, TypeError):
            return _response(400, {"error": "length and count must be valid integers"})

        if not (1 <= count <= MAX_COUNT):
            return _response(400, {"error": f"Count must be between 1 and {MAX_COUNT}"})
        if not (1 <= bytes_per_value <= MAX_BYTES_TOTAL):
            return _response(
                400, {"error": f"Length must be between 1 and {MAX_BYTES_TOTAL}"}
            )

        total_bytes = bytes_per_value * count

        if total_bytes > MAX_BYTES_TOTAL:
            return _response(
                400,
                {
                    "error": f"The combined length of the values exceeds {MAX_BYTES_TOTAL} bytes. Please reduce the count or the length."
                },
            )

        try:
            kms = boto3.client("kms")
            entropy_pool = kms.generate_random(NumberOfBytes=total_bytes)["Plaintext"]
        except (BotoCoreError, ClientError, KeyError) as e:
            return _response(
                500, {"error": "Randomness service unavailable", "details": str(e)}
            )

        hex_chunks = []
        for i in range(count):
            chunk = entropy_pool[i * bytes_per_value : (i + 1) * bytes_per_value]
            hex_chunks.append(chunk.hex())

        timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()

        record_id = str(uuid.uuid4())
        operation_record = {
            "record_id": record_id,
            "timestamp": timestamp,
            "length": bytes_per_value,
            "count": count,
            "values": hex_chunks,
            "seed": entropy_pool.hex(),
        }

        table_name = os.environ.get("DYNAMODB_TABLE_NAME")
        if not table_name:
            return _response(
                500, {"error": "DYNAMODB_TABLE_NAME environment variable not set"}
            )

        try:
            dynamodb = boto3.resource("dynamodb")
            table = dynamodb.Table(table_name)  # type: ignore
            table.put_item(Item=operation_record)
        except (BotoCoreError, ClientError) as e:
            return _response(
                500, {"error": "DynamoDB service unavailable", "details": str(e)}
            )

        response_body = {
            "record_id": record_id,
            "values": hex_chunks,
        }

        return _response(200, response_body)

    except Exception as e:
        return _response(500, {"error": str(e)})
