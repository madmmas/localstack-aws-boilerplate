"""Health check Lambda: read/write DynamoDB. Uses Powertools and configurable client."""

import json
import os
from datetime import datetime, timezone
from typing import Any

import boto3
from aws_lambda_powertools import Logger, Metrics
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger(service_name="health-lambda")
metrics = Metrics(namespace="LocalStackBoilerplate", service="health-lambda")

SERVICE_NAME = "api-gateway-lambda-dynamodb"


def _get_table():
    """Build DynamoDB table reference from env (no endpoint => default boto3 for moto)."""
    region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
    raw = (os.environ.get("DYNAMODB_ENDPOINT") or "").strip()
    # Omit endpoint_url so boto3 uses default (allows moto to patch in tests)
    use_default = raw in ("", "__default__") or os.environ.get("TESTING") == "1"
    if use_default:
        endpoint_url = None
        display = f"default ({region})"
    else:
        endpoint_url = raw or f"http://{os.environ.get('LOCALSTACK_HOSTNAME', 'localstack')}:4566"
        display = endpoint_url
    kwargs = {
        "region_name": region,
        "aws_access_key_id": os.environ.get("AWS_ACCESS_KEY_ID", "test"),
        "aws_secret_access_key": os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
    }
    if endpoint_url:
        kwargs["endpoint_url"] = endpoint_url
    resource = boto3.resource("dynamodb", **kwargs)
    table_name = os.environ.get("HEALTH_TABLE_NAME", "health-check-table")
    return resource.Table(table_name), display


@logger.inject_lambda_context
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context: LambdaContext) -> dict:
    """Write/read health check to DynamoDB and return status."""
    table, endpoint = _get_table()
    timestamp = datetime.now(timezone.utc).isoformat()

    try:
        table.put_item(
            Item={
                "id": "health-check",
                "timestamp": timestamp,
                "status": "healthy",
            }
        )
        response = table.get_item(Key={"id": "health-check"})
        if "Item" in response:
            db_status = "connected"
            last_check = response["Item"].get("timestamp", "unknown")
        else:
            db_status = "no_data"
            last_check = "unknown"

        metrics.add_metric(name="HealthCheckSuccess", unit="Count", value=1)
        return _ok(timestamp, db_status, last_check, endpoint)
    except Exception as e:  # noqa: BLE001
        logger.exception("Health check failed")
        metrics.add_metric(name="HealthCheckFailure", unit="Count", value=1)
        return _error(e, endpoint, table.name)


def _ok(
    timestamp: str, db_status: str, last_check: str, endpoint: str
) -> dict[str, Any]:
    return {
        "statusCode": 200,
        "headers": _headers(),
        "body": json.dumps({
            "status": "healthy",
            "database": db_status,
            "timestamp": timestamp,
            "last_check": last_check,
            "service": SERVICE_NAME,
            "endpoint": endpoint,
        }),
    }


def _error(exc: Exception, endpoint: str, table_name: str) -> dict[str, Any]:
    details: dict[str, Any] = {
        "status": "unhealthy",
        "error": str(exc),
        "error_type": type(exc).__name__,
        "service": SERVICE_NAME,
        "endpoint": endpoint,
        "table_name": table_name,
    }
    if os.environ.get("DEBUG", "false").lower() == "true":
        import traceback
        details["traceback"] = traceback.format_exc()
    return {
        "statusCode": 503,
        "headers": _headers(),
        "body": json.dumps(details),
    }


def _headers() -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
    }
