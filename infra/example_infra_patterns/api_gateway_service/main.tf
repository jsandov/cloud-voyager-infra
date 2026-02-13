# ---------------------------------------------------------------------------
# API Gateway Service Pattern — main.tf
# Service team route attachment to a shared, platform-owned API Gateway
# ---------------------------------------------------------------------------
#
# This pattern demonstrates multi-team API Gateway usage via state isolation:
#
#   1. The PLATFORM team owns the API Gateway, stage, authorizer, and
#      networking resources. Their state is the source of truth for shared
#      infrastructure outputs (api_id, execution_arn, authorizer_id, etc.).
#
#   2. Each SERVICE team (this pattern) reads the platform state via
#      terraform_remote_state and attaches only its own routes using the
#      api_gateway_routes module. One team's `tofu apply` cannot modify
#      another team's routes — state isolation enforces blast-radius control.
#
#   3. Route prefix validation (e.g., /billing) prevents cross-team route
#      collisions at plan time. The platform team assigns each service a
#      unique prefix.
#
# API Gateway v2 (HTTP API) limits to be aware of:
#   - 300 routes per API (soft limit — increasable via AWS support)
#   - 300 integrations per API (hard limit)
#   - 30-second maximum integration timeout for HTTP APIs
#
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Data Sources — Platform Team Remote State
# ---------------------------------------------------------------------------
# Read shared infrastructure outputs from the platform team's state file.
# This is the only coupling point between service and platform state.

data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = var.platform_state_bucket
    key    = var.platform_state_key
    region = var.aws_region
  }
}

# ---------------------------------------------------------------------------
# Lambda Function — Service Backend
# ---------------------------------------------------------------------------
# Each service team deploys its own Lambda function as the backend for its
# API routes. The lambda module handles IAM, logging, encryption, and
# optional VPC/X-Ray configuration.
#
# NOTE: HTTP API v2 has a hard 30-second integration timeout. If your
# Lambda function needs longer execution, consider an async pattern
# (e.g., Step Functions or SQS) instead of synchronous invocation.

module "lambda" {
  source = "../../modules/lambda"

  function_name = "${var.environment}-${var.service_name}"
  description   = "Backend for the ${var.service_name} service (${var.route_prefix} routes)"
  environment   = var.environment
  image_uri     = var.image_uri

  # Resource allocation — tune per service requirements
  memory_size = 256
  timeout     = 30

  # Encryption at rest for environment variables and logs (SC-28)
  kms_key_arn     = var.kms_key_arn
  log_kms_key_arn = var.kms_key_arn

  # VPC deployment for private network isolation (SC-7)
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # Observability
  enable_xray_tracing = true
  log_retention_days  = 30

  tags = var.tags
}

# ---------------------------------------------------------------------------
# API Gateway Routes — Service Route Registration
# ---------------------------------------------------------------------------
# The api_gateway_routes module creates routes on the shared API Gateway
# and grants the necessary Lambda invoke permissions. Each service team
# manages its own routes independently via its own state file.
#
# The route_prefix variable enforces namespace boundaries — all routes
# must start with the assigned prefix (e.g., /billing). This validation
# happens at plan time, preventing accidental cross-team collisions.

module "api_gateway_routes" {
  source = "../../modules/api_gateway_routes"

  # Shared API Gateway references from platform team state
  api_id            = data.terraform_remote_state.platform.outputs.api_id
  api_execution_arn = data.terraform_remote_state.platform.outputs.api_execution_arn

  # Service identity and namespace
  service_name = var.service_name
  route_prefix = var.route_prefix

  # Lambda backend wiring
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn

  # Route definitions — each route is independently managed in state.
  # Adding or removing a route only affects that specific route.
  routes = {
    "POST ${var.route_prefix}/invoices" = {
      authorization_type = "JWT"
      authorizer_id      = data.terraform_remote_state.platform.outputs.authorizer_id
    }
    "GET ${var.route_prefix}/invoices" = {
      authorization_type = "JWT"
      authorizer_id      = data.terraform_remote_state.platform.outputs.authorizer_id
    }
    "GET ${var.route_prefix}/invoices/{invoice_id}" = {
      authorization_type = "JWT"
      authorizer_id      = data.terraform_remote_state.platform.outputs.authorizer_id
    }
  }

  tags = var.tags
}
