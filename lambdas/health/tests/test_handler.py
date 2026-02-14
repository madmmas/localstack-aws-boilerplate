"""Unit tests for health Lambda handler (moto mocks DynamoDB)."""

import json
import os
from unittest.mock import MagicMock

import boto3
from moto import mock_aws

from handler import lambda_handler

TABLE_NAME = "health-check-table"


@mock_aws
def test_lambda_handler_healthy():
    """DynamoDB write/read succeeds -> 200 and database connected."""
    client = boto3.client("dynamodb", region_name="us-east-1")
    client.create_table(
        TableName=TABLE_NAME,
        KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
        BillingMode="PAY_PER_REQUEST",
    )

    os.environ["HEALTH_TABLE_NAME"] = TABLE_NAME
    os.environ["TESTING"] = "1"  # use default boto3 so moto patches

    try:
        event = {}
        context = MagicMock()
        context.aws_request_id = "test-request-id"

        result = lambda_handler(event, context)

        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert body["status"] == "healthy"
        assert body["database"] == "connected"
        assert body["service"] == "api-gateway-lambda-dynamodb"
        assert "timestamp" in body
        assert body["last_check"] != "unknown"
    finally:
        os.environ.pop("HEALTH_TABLE_NAME", None)
        os.environ.pop("TESTING", None)


@mock_aws
def test_lambda_handler_unhealthy_table_missing():
    """Table does not exist -> 503 and error details."""
    os.environ["HEALTH_TABLE_NAME"] = "nonexistent-table"
    os.environ["TESTING"] = "1"

    try:
        event = {}
        context = MagicMock()

        result = lambda_handler(event, context)

        assert result["statusCode"] == 503
        body = json.loads(result["body"])
        assert body["status"] == "unhealthy"
        assert "error" in body
        assert body["service"] == "api-gateway-lambda-dynamodb"
    finally:
        os.environ.pop("HEALTH_TABLE_NAME", None)
        os.environ.pop("TESTING", None)


@mock_aws
def test_lambda_handler_headers():
    """Response includes CORS and JSON headers."""
    client = boto3.client("dynamodb", region_name="us-east-1")
    client.create_table(
        TableName=TABLE_NAME,
        KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
        BillingMode="PAY_PER_REQUEST",
    )
    os.environ["HEALTH_TABLE_NAME"] = TABLE_NAME
    os.environ["TESTING"] = "1"
    try:
        result = lambda_handler({}, MagicMock())
        assert result["headers"]["Content-Type"] == "application/json"
        assert result["headers"]["Access-Control-Allow-Origin"] == "*"
    finally:
        os.environ.pop("HEALTH_TABLE_NAME", None)
        os.environ.pop("TESTING", None)


@mock_aws
def test_lambda_handler_debug_includes_traceback():
    """When DEBUG=true, unhealthy response includes traceback."""
    os.environ["HEALTH_TABLE_NAME"] = "nonexistent"
    os.environ["DEBUG"] = "true"
    os.environ["TESTING"] = "1"
    try:
        result = lambda_handler({}, MagicMock())
        body = json.loads(result["body"])
        assert "traceback" in body
    finally:
        os.environ.pop("HEALTH_TABLE_NAME", None)
        os.environ.pop("DEBUG", None)
        os.environ.pop("TESTING", None)
