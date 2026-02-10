# -----------------------------------------------------------------------------
# S3 Gateway VPC Endpoint
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  policy            = var.s3_endpoint_policy

  route_table_ids = var.route_table_ids

  tags = merge(var.tags, {
    Name        = "${var.environment}-s3-endpoint"
    Environment = var.environment
    ManagedBy   = "opentofu"
  })
}

# -----------------------------------------------------------------------------
# DynamoDB Gateway VPC Endpoint
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  policy            = var.dynamodb_endpoint_policy

  route_table_ids = var.route_table_ids

  tags = merge(var.tags, {
    Name        = "${var.environment}-dynamodb-endpoint"
    Environment = var.environment
    ManagedBy   = "opentofu"
  })
}
