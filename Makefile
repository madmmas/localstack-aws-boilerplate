# Compose base + module overlay. Compose files are in root and compose/
COMPOSE_BASE  := -f docker-compose.yml
COMPOSE_LS_E1 := $(COMPOSE_BASE) -f compose/localstack-us-east-1.yml
COMPOSE_LS_W2 := $(COMPOSE_BASE) -f compose/localstack-us-west-2.yml
COMPOSE_PG    := $(COMPOSE_BASE) -f compose/postgres.yml

.PHONY: help start stop restart
.PHONY: up-localstack-us-east-1 down-localstack-us-east-1
.PHONY: up-localstack-us-west-2 down-localstack-us-west-2
.PHONY: up-postgres down-postgres
.PHONY: up-localstack down-localstack up-all down-all
.PHONY: package init apply destroy test clean output open-localstack open-localstack-w2
.PHONY: package-layer package-hello package-health test-lambdas lint-lambdas

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Docker Compose (modular):'
	@echo '  up-localstack-us-east-1   Start LocalStack us-east-1 (port 4566)'
	@echo '  up-localstack-us-west-2   Start LocalStack us-west-2 (port 4567)'
	@echo '  up-postgres               Start PostgreSQL (port 5432)'
	@echo '  up-localstack             Start both LocalStack regions'
	@echo '  up-all                    Start LocalStack us-east-1 + Postgres'
	@echo '  down-<module>            Stop a module (e.g. down-postgres)'
	@echo '  down-all                  Stop all composed services'
	@echo ''
	@echo 'Legacy / convenience:'
	@echo '  start                     Same as up-localstack-us-east-1'
	@echo '  stop                      Same as down-localstack-us-east-1'
	@echo '  open-localstack           Open LocalStack us-east-1 in browser'
	@echo '  open-localstack-w2        Open LocalStack us-west-2 in browser'
	@echo ''
	@echo 'Lambdas (uv, tests, lint):'
	@echo '  package-layer             Build Lambda layer zip (Powertools)'
	@echo '  package-hello             Build hello Lambda zip'
	@echo '  package-health            Build health Lambda zip'
	@echo '  test-lambdas              Run unit tests with coverage'
	@echo '  lint-lambdas              Run ruff on hello + health'
	@echo ''
	@echo 'Terraform (recover state):'
	@echo '  import-existing           Import existing LocalStack resources after state loss'
	@echo ''
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-25s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ---- LocalStack us-east-1 ----
up-localstack-us-east-1: ## Start LocalStack us-east-1
	docker-compose $(COMPOSE_LS_E1) up -d
	@echo "Waiting for LocalStack (us-east-1) on :4566..."
	@timeout 30 bash -c 'until curl -s http://localhost:4566/_localstack/health > /dev/null; do sleep 1; done' || true
	@echo "LocalStack us-east-1 is ready."

down-localstack-us-east-1: ## Stop LocalStack us-east-1
	docker-compose $(COMPOSE_LS_E1) down

# ---- LocalStack us-west-2 ----
up-localstack-us-west-2: ## Start LocalStack us-west-2
	docker-compose $(COMPOSE_LS_W2) up -d
	@echo "Waiting for LocalStack (us-west-2) on :4567..."
	@timeout 30 bash -c 'until curl -s http://localhost:4567/_localstack/health > /dev/null; do sleep 1; done' || true
	@echo "LocalStack us-west-2 is ready."

down-localstack-us-west-2: ## Stop LocalStack us-west-2
	docker-compose $(COMPOSE_LS_W2) down

# ---- Postgres ----
up-postgres: ## Start PostgreSQL
	docker-compose $(COMPOSE_PG) up -d
	@echo "PostgreSQL is up on :5432 (user=postgres, password=postgres, db=postgres)."

down-postgres: ## Stop PostgreSQL
	docker-compose $(COMPOSE_PG) down

# ---- Combined ----
up-localstack: up-localstack-us-east-1 up-localstack-us-west-2 ## Start both LocalStack regions

down-localstack: down-localstack-us-east-1 down-localstack-us-west-2 ## Stop both LocalStack regions

up-all: up-localstack-us-east-1 up-postgres ## Start LocalStack us-east-1 + Postgres (typical dev stack)

down-all: down-localstack-us-east-1 down-localstack-us-west-2 down-postgres ## Stop all modules
	docker-compose $(COMPOSE_BASE) down 2>/dev/null || true

# ---- Legacy (default: LocalStack us-east-1 only) ----
start: up-localstack-us-east-1 ## Start LocalStack (us-east-1)

stop: down-localstack-us-east-1 ## Stop LocalStack (us-east-1)

restart: stop start ## Restart LocalStack us-east-1

# ---- Open in browser (open on macOS, xdg-open on Linux) ----
OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

open-localstack: ## Open LocalStack us-east-1 in browser
	$(OPEN_CMD) https://app.localstack.cloud

# ---- Lambdas ----
LAMBDAS_DIST := lambdas/dist
PYTHON ?= python3

package: package-hello package-health ## Package both Lambda zips (layer bundled in each for LocalStack)

package-layer: ## Build Lambda layer zip (Powertools)
	@mkdir -p $(LAMBDAS_DIST)
	rm -rf lambdas/layer/build
	mkdir -p lambdas/layer/build/python
	$(PYTHON) -m pip install -q -t lambdas/layer/build/python -r lambdas/layer/requirements.txt
	cd lambdas/layer/build && zip -rq ../../dist/layer.zip python
	@echo "Built $(LAMBDAS_DIST)/layer.zip"

# Bundle layer into Lambda zip so LocalStack finds Powertools (LocalStack does not mount layers to /opt).
# Layer has python/; Lambda PYTHONPATH is /var/task, so we put packages at zip root (not under python/).
package-hello: package-layer ## Build hello Lambda zip (handler + Powertools bundled)
	@mkdir -p $(LAMBDAS_DIST)/staging_hello $(LAMBDAS_DIST)/staging_hello_layer
	rm -rf $(LAMBDAS_DIST)/staging_hello/*
	cp lambdas/hello/handler.py $(LAMBDAS_DIST)/staging_hello/
	cd $(LAMBDAS_DIST)/staging_hello_layer && unzip -oq ../layer.zip && cp -r python/* ../staging_hello/
	cd $(LAMBDAS_DIST)/staging_hello && zip -rq ../hello_lambda.zip .
	@echo "Built $(LAMBDAS_DIST)/hello_lambda.zip"

package-health: package-layer ## Build health Lambda zip (handler + Powertools bundled)
	@mkdir -p $(LAMBDAS_DIST)/staging_health $(LAMBDAS_DIST)/staging_health_layer
	rm -rf $(LAMBDAS_DIST)/staging_health/*
	cp lambdas/health/handler.py $(LAMBDAS_DIST)/staging_health/
	cd $(LAMBDAS_DIST)/staging_health_layer && unzip -oq ../layer.zip && cp -r python/* ../staging_health/
	cd $(LAMBDAS_DIST)/staging_health && zip -rq ../health_lambda.zip .
	@echo "Built $(LAMBDAS_DIST)/health_lambda.zip"

test-lambdas: ## Run unit tests with coverage (hello + health)
	cd lambdas/hello && uv sync --extra dev && uv run pytest --cov --cov-report=term-missing
	cd lambdas/health && uv sync --extra dev && uv run pytest --cov --cov-report=term-missing

lint-lambdas: ## Lint hello and health Lambdas (ruff)
	cd lambdas/hello && uv sync --extra dev && uv run ruff check .
	cd lambdas/health && uv sync --extra dev && uv run ruff check .

# ---- Terraform ----
init: ## Initialize Terraform
	cd iac && terraform init

plan: init package ## Plan Terraform configuration
	cd iac && terraform plan

apply: init package ## Apply Terraform configuration
	cd iac && terraform apply

destroy: ## Destroy Terraform resources
	cd iac && terraform destroy

# Import resources that already exist in LocalStack (e.g. after state was lost). Run once, then make apply.
import-existing: init ## Import DynamoDB table + IAM role if they already exist in LocalStack
	-cd iac && terraform import aws_dynamodb_table.health_table health-check-table
	-cd iac && terraform import aws_iam_role.lambda_role lambda-execution-role
	@echo "Imported. Run 'make apply' to create or update the rest."

output: ## Output all the outputs from Terraform
	cd iac && terraform output

test: ## Test the API (requires API_ID)
	@echo "Usage: make test API_ID=<your-api-id>"
	@if [ -z "$(API_ID)" ]; then \
		echo "Error: API_ID is required"; \
		echo "Get it from: cd iac && terraform output api_gateway_hello_url"; \
		exit 1; \
	fi
	@echo "Testing /hello endpoint:"
	curl "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/hello"
	@echo ""
	@echo ""
	@echo "Testing /hello endpoint with name parameter:"
	curl "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/hello?name=John"
	@echo ""
	@echo ""
	@echo "Testing /health endpoint:"
	curl "http://localhost:4566/restapis/$(API_ID)/dev/_user_request_/health"
	@echo ""

clean: ## Clean up generated files
	rm -rf $(LAMBDAS_DIST)
	rm -rf lambdas/layer/build
	rm -rf $(LAMBDAS_DIST)/staging_hello $(LAMBDAS_DIST)/staging_health $(LAMBDAS_DIST)/staging_hello_layer $(LAMBDAS_DIST)/staging_health_layer
	rm -f lambdas/*.zip
	rm -rf iac/.terraform
	rm -f iac/terraform.tfstate iac/terraform.tfstate.backup
