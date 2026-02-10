# VPC Endpoints Module

Creates Gateway VPC Endpoints for S3 and DynamoDB. Gateway endpoints route traffic to AWS services over the AWS private network instead of the public internet, reducing data transfer costs and improving security posture.

## Usage

### S3 Endpoint Only

```hcl
module "vpc_endpoints" {
  source = "git::https://github.com/jsandov/cloud-voyager-infra.git//infra/modules/vpc_endpoints?ref=v1.0.0"

  vpc_id      = module.vpc.vpc_id
  environment = "prod"

  route_table_ids = [
    module.vpc.public_route_table_id,
    module.vpc.private_route_table_id,
  ]

  tags = {
    Project = "my-project"
  }
}
```

### S3 + DynamoDB Endpoints

```hcl
module "vpc_endpoints" {
  source = "git::https://github.com/jsandov/cloud-voyager-infra.git//infra/modules/vpc_endpoints?ref=v1.0.0"

  vpc_id      = module.vpc.vpc_id
  environment = "prod"

  route_table_ids = [
    module.vpc.public_route_table_id,
    module.vpc.private_route_table_id,
  ]

  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  tags = {
    Project = "my-project"
  }
}
```

### With Restricted S3 Endpoint Policy

```hcl
module "vpc_endpoints" {
  source = "git::https://github.com/jsandov/cloud-voyager-infra.git//infra/modules/vpc_endpoints?ref=v1.0.0"

  vpc_id      = module.vpc.vpc_id
  environment = "prod"

  route_table_ids = [
    module.vpc.private_route_table_id,
  ]

  s3_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSpecificBucket"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource  = [
        "arn:aws:s3:::my-app-bucket",
        "arn:aws:s3:::my-app-bucket/*"
      ]
    }]
  })

  tags = {
    Project = "my-project"
  }
}
```

## Inputs

| Name                       | Type           | Default | Required | Description                                              |
| -------------------------- | -------------- | ------- | -------- | -------------------------------------------------------- |
| `vpc_id`                   | `string`       | --      | yes      | VPC ID to create endpoints in                            |
| `environment`              | `string`       | --      | yes      | Environment name for tagging (dev, staging, prod)        |
| `route_table_ids`          | `list(string)` | --      | yes      | Route table IDs to associate with Gateway endpoints      |
| `enable_s3_endpoint`       | `bool`         | `true`  | no       | Create an S3 Gateway VPC Endpoint                        |
| `enable_dynamodb_endpoint` | `bool`         | `false` | no       | Create a DynamoDB Gateway VPC Endpoint                   |
| `s3_endpoint_policy`       | `string`       | `null`  | no       | Custom IAM policy for S3 endpoint (null = full access)   |
| `dynamodb_endpoint_policy` | `string`       | `null`  | no       | Custom IAM policy for DynamoDB endpoint (null = full access) |
| `tags`                     | `map(string)`  | `{}`    | no       | Additional tags for all resources                        |

## Outputs

| Name                              | Description                                              |
| --------------------------------- | -------------------------------------------------------- |
| `s3_endpoint_id`                  | ID of the S3 Gateway endpoint (null if disabled)         |
| `s3_endpoint_prefix_list_id`      | Prefix list ID for S3 (use in security group rules)      |
| `dynamodb_endpoint_id`            | ID of the DynamoDB Gateway endpoint (null if disabled)   |
| `dynamodb_endpoint_prefix_list_id`| Prefix list ID for DynamoDB (use in security group rules)|

## Why Gateway Endpoints?

- **No cost**: Gateway endpoints for S3 and DynamoDB are free
- **No NAT required**: Private subnets can access S3/DynamoDB without a NAT Gateway
- **Better performance**: Traffic stays on the AWS backbone network
- **Security**: Traffic never traverses the public internet

## FedRAMP Controls

| Control | Requirement                   | Implementation                                        |
| ------- | ----------------------------- | ----------------------------------------------------- |
| SC-7    | Boundary protection           | Traffic routed over AWS private network, not internet  |
| AC-4    | Information flow enforcement  | Optional endpoint policies restrict access to specific buckets/tables |
| SC-8    | Transmission confidentiality  | All traffic stays within AWS infrastructure            |
