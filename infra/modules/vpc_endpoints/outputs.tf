output "s3_endpoint_id" {
  description = "The ID of the S3 Gateway VPC Endpoint (null if disabled)"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

output "s3_endpoint_prefix_list_id" {
  description = "The prefix list ID of the S3 endpoint for use in security group rules"
  value       = try(aws_vpc_endpoint.s3[0].prefix_list_id, null)
}

output "dynamodb_endpoint_id" {
  description = "The ID of the DynamoDB Gateway VPC Endpoint (null if disabled)"
  value       = try(aws_vpc_endpoint.dynamodb[0].id, null)
}

output "dynamodb_endpoint_prefix_list_id" {
  description = "The prefix list ID of the DynamoDB endpoint for use in security group rules"
  value       = try(aws_vpc_endpoint.dynamodb[0].prefix_list_id, null)
}
