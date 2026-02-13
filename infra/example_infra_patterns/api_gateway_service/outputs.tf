# ---------------------------------------------------------------------------
# API Gateway Service Pattern — outputs.tf
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# API Gateway Routes
# ---------------------------------------------------------------------------

output "route_ids" {
  description = "Map of route key to API Gateway route ID for this service's routes"
  value       = module.api_gateway_routes.route_ids
}

output "route_keys" {
  description = "List of route keys managed by this service (e.g., POST /billing/invoices)"
  value       = module.api_gateway_routes.route_keys
}

output "integration_id" {
  description = "The ID of the API Gateway Lambda integration for this service"
  value       = module.api_gateway_routes.integration_id
}

# ---------------------------------------------------------------------------
# Lambda Function
# ---------------------------------------------------------------------------

output "lambda_function_name" {
  description = "Name of the Lambda function backing this service's routes"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function backing this service's routes"
  value       = module.lambda.function_arn
}
