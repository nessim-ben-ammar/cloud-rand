import boto3
from botocore.exceptions import BotoCoreError, ClientError
import datetime
import json
import os
import uuid

# Constants
MAX_COUNT = 512
MAX_BYTES_TOTAL = 512
ENTROPY_POOL_CHUNK_SIZE = 1024
MAX_RANGE_BITS = 64


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
        request_data = json.loads(event.get("body", "{}"))

        try:
            range_min = int(request_data["min"])
            range_max = int(request_data["max"])
            count = int(request_data.get("count", 1))
        except (KeyError, ValueError, TypeError):
            return _response(
                400, {"error": "min, max, and count must be valid integers"}
            )

        if not (1 <= count <= MAX_COUNT):
            return _response(400, {"error": f"Count must be between 1 and {MAX_COUNT}"})
        if range_min >= range_max:
            return _response(400, {"error": "min must be strictly less than max"})

        range_size = range_max - range_min + 1

        if range_size.bit_length() > MAX_RANGE_BITS:
            return _response(
                400, {"error": f"Requested range exceeds {MAX_RANGE_BITS} bits"}
            )

        bytes_per_sample = (range_size.bit_length() + 7) // 8

        if bytes_per_sample * count > MAX_BYTES_TOTAL:
            return _response(
                400,
                {
                    "error": f"The combined length of the values exceeds {MAX_BYTES_TOTAL} bytes. Please reduce the count or the range."
                },
            )

        try:
            kms = boto3.client("kms")
            entropy_seed = kms.generate_random(NumberOfBytes=ENTROPY_POOL_CHUNK_SIZE)[
                "Plaintext"
            ]
        except (BotoCoreError, ClientError, KeyError) as e:
            return _response(
                500, {"error": "Randomness service unavailable", "details": str(e)}
            )

        entropy_pool = entropy_seed

        entropy_space_size = 1 << (bytes_per_sample * 8)
        unbiased_cutoff = entropy_space_size - (entropy_space_size % range_size)

        random_values = []

        for _ in range(count):
            while True:
                if len(entropy_pool) < bytes_per_sample:
                    try:
                        new_bytes = kms.generate_random(
                            NumberOfBytes=ENTROPY_POOL_CHUNK_SIZE
                        )["Plaintext"]
                    except (BotoCoreError, ClientError, KeyError) as e:
                        return _response(
                            500,
                            {
                                "error": "Randomness service unavailable",
                                "details": str(e),
                            },
                        )
                    entropy_seed += new_bytes
                    entropy_pool += new_bytes

                candidate_value = int.from_bytes(
                    entropy_pool[:bytes_per_sample], "big", signed=False
                )
                entropy_pool = entropy_pool[bytes_per_sample:]

                if candidate_value >= unbiased_cutoff:
                    continue

                final_value = range_min + (candidate_value % range_size)
                random_values.append(final_value)
                break

        timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()

        record_id = str(uuid.uuid4())
        operation_record = {
            "record_id": record_id,
            "timestamp": timestamp,
            "range_min": range_min,
            "range_max": range_max,
            "count": count,
            "values": random_values,
            "seed": entropy_seed.hex(),
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
            "values": random_values,
        }

        return _response(200, response_body)

    except Exception as e:
        return _response(500, {"error": str(e)})
