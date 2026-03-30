# ============================================================================
# AWS Lambda Functions – IAM, Roles, and Deployment
# ============================================================================
# Resource Summary Table:
# ----------------------------------------------------------------------------
# | Resource Type                    | Name / Identifier           | Purpose & Notes                                  |
# |---------------------------------|----------------------------|--------------------------------------------------|
# | data.aws_iam_policy_document     | lambda_assume_role         | Trust policy allowing Lambda service to assume role |
# | aws_iam_role                     | lambda_role                | IAM role for Lambda function execution          |
# | aws_iam_role_policy_attachment   | lambda_basic_execution     | Attaches AWSLambdaBasicExecutionRole to Lambda role |
# | aws_lambda_function              | this                       | Creates the Lambda function, supports environment variables, VPC config, and lifecycle settings |
#
# Notes:
# - One IAM role per Lambda function is created dynamically using `for_each`.
# - Lambda functions reference artifacts from S3 and support optional `source_code_hash`.
# - Environment variables are merged from global and per-function variables.
# - VPC configuration is optional and only applied if subnet IDs and security groups are provided.
# - Lambda functions have active X-Ray tracing enabled.
# - Optional hardening (default on): SQS DLQ, code signing config, reserved concurrency, KMS for env.
# - `prevent_destroy` ensures Lambda functions are not accidentally destroyed.
# - `create_before_destroy` ensures safe updates.
# - Tags can be applied both globally (`var.tags`) and per-function (`var.function_tags`).
# ============================================================================

locals {
  lambda_has_nonempty_env = {
    for k, fn in var.lambdas : k =>(
      length(var.environment_variables) > 0 || length(fn.environment_variables) > 0
    )
  }
}

# AWS-managed key used to encrypt environment variables at rest (CKV_AWS_173 when env is set).
data "aws_kms_key" "lambda_env" {
  key_id = "alias/aws/lambda"
}

# Shared dead-letter queue for all functions in this module (CKV_AWS_116).
resource "aws_sqs_queue" "lambda_dlq" {
  count = var.lambda_hardening && length(var.lambdas) > 0 ? 1 : 0
  kms_key_arn = var.lambda_hardening && local.lambda_has_nonempty_env[each.key] ? data.aws_kms_key.lambda_env.arn : null
  name_prefix               = "lambda-dlq-"
  message_retention_seconds = 1209600
  tags                      = var.tags
}

# Code signing profile + config (CKV_AWS_272). UntrustedArtifactOnDeployment=Warn keeps unsigned S3 zips usable.
resource "aws_signer_signing_profile" "lambda" {
  count = var.lambda_hardening && length(var.lambdas) > 0 ? 1 : 0

  platform_id = "AWSLambda-SHA384-ECDSA"
  name_prefix = "lambda-signing-"
}

resource "aws_lambda_code_signing_config" "this" {
  count = var.lambda_hardening && length(var.lambdas) > 0 ? 1 : 0

  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.lambda[0].version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = var.code_signing_untrusted_behavior
  }
}

data "aws_iam_policy_document" "lambda_dlq" {
  count = var.lambda_hardening && length(var.lambdas) > 0 ? 1 : 0

  statement {
    sid       = "LambdaDLQ"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.lambda_dlq[0].arn]
  }
}

resource "aws_iam_role_policy" "lambda_dlq" {
  for_each = var.lambda_hardening && length(var.lambdas) > 0 ? var.lambdas : {}

  name   = "${each.key}-dlq"
  role   = aws_iam_role.lambda_role[each.key].id
  policy = data.aws_iam_policy_document.lambda_dlq[0].json
}

# ============================================================================
# IAM Trust Policy: Lambda → IAM Role
# ============================================================================
# Allows AWS Lambda service (lambda.amazonaws.com) to assume this role.
data "aws_iam_policy_document" "lambda_assume_role" {
  for_each = var.lambdas

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# ============================================================================
# IAM Role for Lambda Functions
# ============================================================================
# Core execution role for Lambda functions with basic execution permissions.
resource "aws_iam_role" "lambda_role" {
  for_each = var.lambdas

  name               = "${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role[each.key].json
  tags               = var.tags
}

# ============================================================================
# Attach AWSLambdaBasicExecutionRole Policy
# ============================================================================
# Grants Lambda permission to write logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  for_each = var.lambdas

  role       = aws_iam_role.lambda_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# Lambda Function Deployment
# ============================================================================
# Creates Lambda functions with the following configurable features:
# - S3-based deployment package
# - Handler, runtime, timeout, and memory size
# - Optional environment variables (merged global + function-specific)
# - Optional VPC configuration
# - Active X-Ray tracing
# - Lifecycle protection and safe replacement
resource "aws_lambda_function" "this" {
  for_each = var.lambdas

  function_name = each.key
  description   = each.value.description
  role          = aws_iam_role.lambda_role[each.key].arn
  handler       = each.value.handler
  runtime       = each.value.runtime

  s3_bucket = var.lambda_artifacts_bucket
  s3_key    = each.value.s3_key

  source_code_hash = lookup(each.value, "source_code_hash", null)

  timeout     = each.value.timeout
  memory_size = each.value.memory_size

  publish = true

  reserved_concurrent_executions = var.lambda_hardening ? var.reserved_concurrent_executions : null

  code_signing_config_arn = var.lambda_hardening && length(var.lambdas) > 0 ? aws_lambda_code_signing_config.this[0].arn : null

  dynamic "dead_letter_config" {
    for_each = var.lambda_hardening && length(var.lambdas) > 0 ? [1] : []
    content {
      target_arn = aws_sqs_queue.lambda_dlq[0].arn
    }
  }

  kms_key_arn = var.lambda_hardening && local.lambda_has_nonempty_env[each.key] ? data.aws_kms_key.lambda_env.arn : null

  dynamic "environment" {
    for_each = (
      length(var.environment_variables) > 0 ||
      length(each.value.environment_variables) > 0
    ) ? [1] : []

    content {
      variables = merge(
        var.environment_variables,
        each.value.environment_variables
      )
    }
  }

  dynamic "vpc_config" {
    for_each = (
      var.vpc_subnet_ids != null &&
      var.vpc_security_group_ids != null
    ) ? [1] : []

    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = var.lambda_hardening && length(var.lambdas) > 0 ? [for k in keys(var.lambdas) : aws_iam_role_policy.lambda_dlq[k]] : []

  tags = merge(
    var.tags,
    var.function_tags
  )

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
  }
}