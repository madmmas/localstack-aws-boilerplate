# Health Lambda

Health check that writes/reads DynamoDB. Uses AWS Lambda Powertools and the shared layer. Unit tests use **moto** to mock DynamoDB.

- **Handler:** `handler.lambda_handler`
- **Tests:** `uv run pytest --cov` or `make test-lambdas` from repo root (set `TESTING=1` for moto)
- **Lint:** `uv run ruff check .` or `make lint-lambdas`
