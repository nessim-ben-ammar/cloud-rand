import boto3
import datetime
import json
import random
import uuid
from botocore.exceptions import BotoCoreError, ClientError

# Constants
MAX_COUNT = 1024
MAX_BYTES_TOTAL = 1024
KMS_CHUNK_SIZE = 1024


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    """
    Lambda handler to generate verifiable random integers using AWS KMS.

    Request body JSON:
    {
        "min": int,
        "max": int,
        "count": int (default=1)
    }

    Returns:
    {
        "record_id": UUID,
        "values": List[int]
    }
    """
    try:
        body = json.loads(event.get("body", "{}"))

        try:
            length = int(body["length"])
            count = int(body.get("count", 1))
        except (KeyError, ValueError, TypeError):
            return _response(400, {"error": "lenth and count must be valid integers"})

        if not (1 <= count <= MAX_COUNT):
            return _response(400, {"error": f"Count must be between 1 and {MAX_COUNT}"})
        if not (1 <= length <= MAX_BYTES_TOTAL):
            return _response(
                400, {"error": "Length must be between 1 and {MAX_BYTES_TOTAL}"}
            )

        size = length * count

        if size > MAX_BYTES_TOTAL:
            return _response(
                400,
                {
                    "error": "The combined length of the values exceeds {MAX_BYTES_TOTAL} bytes. Please reduce the count or the length."
                },
            )

        try:
            kms = boto3.client("kms")
            src_bytes = kms.generate_random(NumberOfBytes=size)["Plaintext"]
        except (BotoCoreError, ClientError, KeyError) as e:
            return _response(
                500, {"error": "Randomness service unavailable", "details": str(e)}
            )

        random_values = []

        for i in range(count):
            random_value = src_bytes[i * length : (i + 1) * length]
            random_values.append(random_value.hex())  # Convert bytes to hex string

        timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()

        operation_record = {
            "record_id": str(uuid.uuid4()),
            "timestamp": timestamp,
            "length": length,
            "count": count,
            "values": random_values,
        }

        response_body = {
            "record_id": operation_record["record_id"],
            "src_chunk": src_bytes.hex(),  # Convert bytes to hex string
            "values": operation_record["values"],
        }

        return _response(200, response_body)

    except Exception as e:
        return _response(500, {"error": str(e)})
