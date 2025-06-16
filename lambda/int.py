import boto3
import datetime
import json
import random
import uuid
from botocore.exceptions import BotoCoreError, ClientError

# Constants
MAX_COUNT = 512
MAX_BYTES_TOTAL = 512
KMS_CHUNK_SIZE = 1024
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
        body = json.loads(event.get("body", "{}"))

        try:
            range_min = int(body["min"])
            range_max = int(body["max"])
            count = int(body.get("count", 1))
        except (KeyError, ValueError, TypeError):
            return _response(
                400, {"error": "min, max, and count must be valid integers"}
            )

        if not (1 <= count <= MAX_COUNT):
            return _response(400, {"error": f"Count must be between 1 and {MAX_COUNT}"})
        if range_min >= range_max:
            return _response(400, {"error": "min must be strictly less than max"})

        # Calculate the size of the requested range
        range_size = range_max - range_min + 1

        # Ensure range does not exceed 64 bits
        if range_size.bit_length() > MAX_RANGE_BITS:
            return _response(
                400, {"error": f"Requested range exceeds {MAX_RANGE_BITS} bits"}
            )

        # Calculate the number of bytes needed to cover the range
        bytes_per_sample = (range_size.bit_length() + 7) // 8

        if bytes_per_sample * count > MAX_BYTES_TOTAL:
            return _response(
                400,
                {
                    "error": "The combined length of the values exceeds 512 bytes. Please reduce the count or the range."
                },
            )

        try:
            kms = boto3.client("kms")
            src_bytes = kms.generate_random(NumberOfBytes=KMS_CHUNK_SIZE)["Plaintext"]
        except (BotoCoreError, ClientError, KeyError) as e:
            return _response(
                500, {"error": "Randomness service unavailable", "details": str(e)}
            )

        entropy_pool = (
            src_bytes  # Keep original src_bytes for audit purposes if needed later
        )

        # Compute max acceptable value to reduce rejection rate (bias avoidance)
        entropy_space_size = 1 << (bytes_per_sample * 8)
        unbiased_cutoff = entropy_space_size - (entropy_space_size % range_size)

        random_values = []

        for _ in range(count):
            value_found = False
            while not value_found:
                # Refill entropy pool if not enough bytes
                if len(entropy_pool) < bytes_per_sample:
                    try:
                        new_bytes = kms.generate_random(NumberOfBytes=KMS_CHUNK_SIZE)[
                            "Plaintext"
                        ]
                    except (BotoCoreError, ClientError, KeyError) as e:
                        return _response(
                            500,
                            {
                                "error": "Randomness service unavailable",
                                "details": str(e),
                            },
                        )

                    src_bytes += new_bytes  # May be logged or stored later for audit
                    entropy_pool += new_bytes

                # Get next candidate number from entropy
                candidate_value = int.from_bytes(
                    entropy_pool[:bytes_per_sample], "big", signed=False
                )
                entropy_pool = entropy_pool[bytes_per_sample:]

                if candidate_value >= unbiased_cutoff:
                    continue  # Try again

                final_value = range_min + (candidate_value % range_size)
                random_values.append(final_value)
                value_found = True

        timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()

        operation_record = {
            "record_id": str(uuid.uuid4()),
            "timestamp": timestamp,
            "range_min": range_min,
            "range_max": range_max,
            "count": count,
            "values": random_values,
        }

        response_body = {
            "record_id": operation_record["record_id"],
            "values": operation_record["values"],
        }

        return _response(200, response_body)

    except Exception as e:
        return _response(500, {"error": str(e)})
