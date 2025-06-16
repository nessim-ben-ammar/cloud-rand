import boto3
import datetime
import json
import random
import uuid


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        min_val = int(body.get("min"))
        max_val = int(body.get("max"))
        count = int(body.get("count", 1))

        if not (1 <= count <= 100):
            return _response(400, {"error": "Count must be between 1 and 100"})
        if min_val > max_val:
            return _response(400, {"error": "min must be <= max"})

        values = [random.randint(min_val, max_val) for _ in range(count)]
        request_id = str(uuid.uuid4())
        timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()

        record = {"requestId": request_id, "values": values}

        return _response(200, record)

    except Exception as e:
        return _response(500, {"error": str(e)})
