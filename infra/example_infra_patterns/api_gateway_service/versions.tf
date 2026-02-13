terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend (uncomment when ready to migrate from local state):
  #
  # Each service team uses its own state file, isolated from the platform
  # team and other service teams. This ensures one team's `tofu apply`
  # cannot affect another team's resources.
  #
  # To migrate:
  #   1. Uncomment the backend block below
  #   2. Run: tofu init -migrate-state
  #   3. Confirm the migration when prompted
  #
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "services/billing/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
