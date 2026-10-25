SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

ENV ?= dev
TF_ROOTS := terraform terraform/bootstrap
DOC_DIRS := terraform terraform/bootstrap $(wildcard terraform/modules/*)
TF_TEST_DIRS := terraform/bootstrap $(wildcard terraform/modules/*)
ENVS := dev prod
TF := terraform -chdir=terraform
BOOTSTRAP := terraform -chdir=terraform/bootstrap
REGION ?= us-east-1
# The state bucket defaults to the one the local bootstrap created. The GitHub
# workflow sets STATE_BUCKET and STATE_REGION explicitly.
STATE_BUCKET ?= $(shell $(BOOTSTRAP) output -raw bucket_name 2>/dev/null)
STATE_REGION ?= $(or $(shell $(BOOTSTRAP) output -raw region 2>/dev/null),us-east-1)
STATE_KMS_KEY_ID ?= $(shell $(BOOTSTRAP) output -raw kms_key_arn 2>/dev/null)
PLAN_FLAGS ?=
LOCK_ID ?=
CONFIRM ?=
CHECKOV_VERSION := 3.3.30
ACTIONLINT_VERSION := 1.7.12.25
FUNCTION_DIR := functions/info
BUILD_DIR := build/functions/info
ENV_DIR := terraform/environments/$(ENV)
TFVARS := environments/$(ENV)/terraform.tfvars
TFARGS := -var-file=$(TFVARS) -var region=$(REGION)
PLAN_FILE := $(ENV)-$(REGION).tfplan

.PHONY: help bootstrap-plan bootstrap-apply check-env check-state check-plan init unlock fmt fmt-check validate lint scan test function-lint function-test function-integration docs actionlint local-up local-down local-invoke build check plan apply destroy verify logs

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

bootstrap-plan: ## Plan the state bucket (BUCKET=<globally unique name> [REGION=])
	@test -n "$(BUCKET)" || { echo "usage: make bootstrap-plan BUCKET=<globally-unique-name> [REGION=us-east-1]"; exit 1; }
	$(BOOTSTRAP) init -input=false
	$(BOOTSTRAP) plan -input=false -out=tfplan -var bucket_name=$(BUCKET) -var region=$(REGION)

bootstrap-apply: ## Apply the plan saved by bootstrap-plan (review it first)
	$(BOOTSTRAP) apply -input=false tfplan

check-env:
	@test -d $(ENV_DIR) || { echo "unknown ENV '$(ENV)': $(ENV_DIR) does not exist"; exit 1; }

check-state:
	@test -n "$(STATE_BUCKET)" || { echo "set STATE_BUCKET, or run make bootstrap-plan and bootstrap-apply to create the state bucket"; exit 1; }

check-plan:
	@test -f terraform/$(PLAN_FILE) || { echo "no saved plan for $(ENV) in $(REGION): run make plan first"; exit 1; }

init: check-env check-state ## Connect to the shared state for ENV and REGION
	$(TF) init -input=false -reconfigure \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="key=info-api-extended/$(ENV)/$(REGION)/terraform.tfstate" \
		-backend-config="region=$(STATE_REGION)" \
		-backend-config="use_lockfile=true" \
		$(if $(STATE_KMS_KEY_ID),-backend-config="kms_key_id=$(STATE_KMS_KEY_ID)")

unlock: check-env ## Release a stuck state lock. Needs LOCK_ID and CONFIRM=<ENV>
	@test -n "$(LOCK_ID)" || { echo "set LOCK_ID to the ID in the 'state is locked' error"; exit 1; }
	@test "$(CONFIRM)" = "$(ENV)" || { echo "refusing to unlock: run make unlock ENV=$(ENV) CONFIRM=$(ENV) LOCK_ID=<id>"; exit 1; }
	@$(MAKE) --no-print-directory init
	$(TF) force-unlock -force $(LOCK_ID)

fmt: ## Rewrite Terraform files to canonical format
	terraform fmt -recursive terraform

fmt-check: ## Fail if any Terraform file is not formatted
	terraform fmt -check -recursive terraform

validate: ## Validate every Terraform root without touching a backend
	@for dir in $(TF_ROOTS); do \
		echo "validate $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false >/dev/null; \
		terraform -chdir=$$dir validate; \
	done

lint: ## Run tflint on every module
	tflint --init --config=$(CURDIR)/.tflint.hcl
	tflint --recursive --config=$(CURDIR)/.tflint.hcl

scan: ## Run checkov security checks (pinned version, no install needed)
	uvx --from checkov==$(CHECKOV_VERSION) checkov --config-file .checkov.yaml

test: ## Run terraform test: every module, then the root once per environment (mocked AWS, no credentials)
	@for dir in $(TF_TEST_DIRS); do \
		echo "test $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false >/dev/null; \
		terraform -chdir=$$dir test; \
	done
	@terraform -chdir=terraform init -backend=false -input=false >/dev/null
	@for env in $(ENVS); do \
		echo "test terraform ($$env)"; \
		terraform -chdir=terraform test -var-file=environments/$$env/terraform.tfvars; \
	done

docs: ## Regenerate the Terraform README tables (needs terraform-docs 0.24.0)
	@for dir in $(DOC_DIRS); do \
		terraform-docs --config .terraform-docs.yml $$dir >/dev/null; \
	done

actionlint: ## Lint the GitHub Actions workflows (pinned version, no install needed)
	uvx --from actionlint-py==$(ACTIONLINT_VERSION) actionlint

function-lint: ## Lint and format-check the Lambda function
	cd $(FUNCTION_DIR) && uv run ruff check . && uv run ruff format --check .

function-test: ## Run the Lambda unit tests (no database needed)
	cd $(FUNCTION_DIR) && uv run pytest -m "not integration"

function-integration: ## Run the integration tests against the PostgreSQL in the DB_* variables
	cd $(FUNCTION_DIR) && uv run pytest -m integration

local-up: ## Start a local PostgreSQL in Docker (creates local/.env from the example)
	@test -f local/.env || cp local/.env.example local/.env
	docker compose --env-file local/.env -f local/docker-compose.yml up -d --wait

local-down: ## Stop the local PostgreSQL and discard its data
	docker compose --env-file local/.env -f local/docker-compose.yml down -v

local-invoke: ## Run the real handler once against the database in local/.env
	@test -f local/.env || { echo "missing local/.env: run make local-up first"; exit 1; }
	set -a && . local/.env && set +a && cd $(FUNCTION_DIR) && uv run python scripts/invoke_local.py

build: ## Package the Lambda function into build/ (locked, hash-verified, linux arm64)
	rm -rf build
	mkdir -p $(BUILD_DIR)
	cd $(FUNCTION_DIR) && uv export --frozen --no-dev --no-emit-project -o $(CURDIR)/build/requirements.txt
	uv pip install --quiet --target $(BUILD_DIR) --python-platform aarch64-manylinux2014 --python-version 3.13 --require-hashes --no-deps -r build/requirements.txt
	cp -R $(FUNCTION_DIR)/src/info_api $(BUILD_DIR)/
	find $(BUILD_DIR) -name __pycache__ -type d -prune -exec rm -rf {} +

plan: build init ## Plan ENV in REGION and save the plan (PLAN_FLAGS=-destroy plans a destroy)
	$(TF) plan -input=false -lock-timeout=60s $(TFARGS) $(PLAN_FLAGS) -out=$(PLAN_FILE)

apply: check-plan init ## Apply the plan saved by make plan, and nothing else
	$(TF) apply -input=false -lock-timeout=60s $(PLAN_FILE)

destroy: check-env ## Destroy ENV in REGION. Needs CONFIRM=<ENV>, and Terraform still asks
	@test "$(CONFIRM)" = "$(ENV)" || { echo "refusing to destroy '$(ENV)': run make destroy ENV=$(ENV) CONFIRM=$(ENV)"; exit 1; }
	@$(MAKE) --no-print-directory build init
	$(TF) destroy -lock-timeout=60s $(TFARGS)

verify: init ## Call the deployed endpoint and print the response
	curl -sS --fail-with-body "$$($(TF) output -raw info_url)" | jq .

logs: init ## Tail the Lambda's CloudWatch logs (needs the AWS CLI)
	aws logs tail "/aws/lambda/$$($(TF) output -raw lambda_function_name)" --region $(REGION) --since 15m --follow

check: fmt-check validate lint actionlint scan test function-lint function-test ## Everything that needs no database or AWS account
