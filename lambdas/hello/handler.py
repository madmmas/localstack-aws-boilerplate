"""Hello Lambda: returns a greeting. Uses Powertools for logging and metrics."""

import json

from aws_lambda_powertools import Logger, Metrics
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger(service_name="hello-lambda")
metrics = Metrics(namespace="LocalStackBoilerplate", service="hello-lambda")


@logger.inject_lambda_context
@metrics.log_metrics(capture_cold_start_metric=True)
def lambda_handler(event: dict, context: LambdaContext) -> dict:
    """Return a greeting. Name comes from queryStringParameters or default 'World'."""
    query = event.get("queryStringParameters") or {}
    name = query.get("name", "World")

    logger.info("Hello invoked", extra={"greeting_name": name})
    metrics.add_metric(name="HelloInvocations", unit="Count", value=1)

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps({
            "message": f"Hello, {name}!",
            "event": event,
        }),
    }
