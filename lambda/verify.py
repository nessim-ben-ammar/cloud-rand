import boto3
import json
import logging
import os
from botocore.exceptions import BotoCoreError, ClientError
import decimal
from typing import Any, Dict

TABLE_NAME = os.getenv("DYNAMODB_TABLE_NAME")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def _response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Helper to format API Gateway responses."""
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
        "isBase64Encoded": False,
    }


def _json_safe(obj: Any) -> Any:
    """Recursively convert Decimal values to built-in types."""
    if isinstance(obj, list):
        return [_json_safe(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: _json_safe(v) for k, v in obj.items()}
    elif isinstance(obj, decimal.Decimal):
        # Convert to int if no fractional part, else float
        return int(obj) if obj % 1 == 0 else float(obj)
    else:
        return obj


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    try:
        record_id = event.get("queryStringParameters", {}).get("record_id")
        if not record_id:
            return _response(400, {"error": "record_id query parameter required"})

        table_name = TABLE_NAME
        if not table_name:
            return _response(
                500, {"error": "DYNAMODB_TABLE_NAME environment variable not set"}
            )

        try:
            table = boto3.resource("dynamodb").Table(table_name)  # type: ignore
            response = table.get_item(Key={"record_id": record_id})
        except (BotoCoreError, ClientError) as e:
            return _response(
                500, {"error": "DynamoDB service unavailable", "details": str(e)}
            )

        item = response.get("Item")
        if not item:
            return _response(404, {"error": "Item not found"})

        # Reorder fields for response according to clarified order
        ordered_item = {}
        # 1. record_id
        if "record_id" in item:
            ordered_item["record_id"] = item["record_id"]
        # 2. timestamp
        if "timestamp" in item:
            ordered_item["timestamp"] = item["timestamp"]
        # 3. request entries
        if "length" in item:
            ordered_item["length"] = item["length"]
        if "range_min" in item:
            ordered_item["range_min"] = item["range_min"]
        if "range_max" in item:
            ordered_item["range_max"] = item["range_max"]
        if "count" in item:
            ordered_item["count"] = item["count"]
        # 4. values
        if "values" in item:
            ordered_item["values"] = item["values"]
        # 5. seed
        if "seed" in item:
            ordered_item["seed"] = item["seed"]
        # Add any extra fields not in the preferred order
        for k in item:
            if k not in ordered_item:
                ordered_item[k] = item[k]

        return _response(200, _json_safe(ordered_item))
    except Exception as e:  # pragma: no cover - unexpected errors
        logger.exception("Unhandled error")
        return _response(500, {"error": str(e)})
