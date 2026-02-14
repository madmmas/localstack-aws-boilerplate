"""Unit tests for hello Lambda handler."""

import json
from unittest.mock import MagicMock

from handler import lambda_handler


def test_lambda_handler_default_name():
    """No query params -> greeting with 'World'."""
    event = {"queryStringParameters": None}
    context = MagicMock()
    context.aws_request_id = "test-request-id"

    result = lambda_handler(event, context)

    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["message"] == "Hello, World!"
    assert "event" in body


def test_lambda_handler_with_name():
    """queryStringParameters.name -> greeting with that name."""
    event = {"queryStringParameters": {"name": "Jane"}}
    context = MagicMock()
    context.aws_request_id = "test-request-id"

    result = lambda_handler(event, context)

    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["message"] == "Hello, Jane!"


def test_lambda_handler_empty_query():
    """Empty query params -> default 'World'."""
    event = {"queryStringParameters": {}}
    context = MagicMock()

    result = lambda_handler(event, context)

    assert result["statusCode"] == 200
    body = json.loads(result["body"])
    assert body["message"] == "Hello, World!"


def test_lambda_handler_headers():
    """Response includes CORS and JSON headers."""
    event = {}
    context = MagicMock()

    result = lambda_handler(event, context)

    assert result["headers"]["Content-Type"] == "application/json"
    assert result["headers"]["Access-Control-Allow-Origin"] == "*"
