variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "test", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, qa, prod."
  }
}

variable "aws_region" {
  description = "AWS region where the Lex bot is deployed (e.g., eu-west-2)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID hosting the Lex bot"
  type        = string
}

variable "aws_account_name" {
  description = "Human-friendly AWS account name used for tagging"
  type        = string
}

