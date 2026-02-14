# Hello Lambda

Returns a greeting. Uses AWS Lambda Powertools (Logger + Metrics) from common deps (bundled in zip).

- **Handler:** `handler.lambda_handler`
- **Tests:** `uv run pytest --cov` or `make test-lambdas` from repo root
- **Lint:** `uv run ruff check .` or `make lint-lambdas`
