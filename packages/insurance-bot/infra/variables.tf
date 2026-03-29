
variable "environment" {
  type = string
  default   = "dev"
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

variable "lambda_artifacts_bucket" {
  description = "S3 bucket for Lambda artifacts"
  type        = string
}