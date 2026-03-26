# ============================================================================
# AWS Lex V2 – IAM Role & Permissions Setup
# ============================================================================
# This file defines all IAM resources required for the Lex V2 bot to operate.
#
# It includes:
# - Trust relationship allowing Lex to assume the role
# - Core IAM role used by the bot
# - Policies for:
#     • Text-to-speech via Amazon Polly
#     • CloudWatch logging for observability
#     • Optional Lambda invocation for fulfillment hooks
#
# Design Principles:
# - Least privilege access (only required permissions granted)
# - Modular and dynamic (Lambda permissions only created when needed)
# - Fully taggable for governance and cost tracking
#
# NOTE:
# - Managed policy (AmazonLexFullAccess) is intentionally NOT used to avoid
#   over-permissioning. Instead, fine-grained policies are defined below.
# ============================================================================

# ============================================================================
# Trust Relationship (Lex Service → IAM Role)
# ============================================================================
# Allows AWS Lex V2 service (lexv2.amazonaws.com) to assume this IAM role.
# This is mandatory for Lex bots to function.

data "aws_iam_policy_document" "lex_trust_relationship" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lexv2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# ============================================================================
# Trust Relationship (Lex Service → IAM Role)
# ============================================================================
# Allows AWS Lex V2 service (lexv2.amazonaws.com) to assume this IAM role.
# This is mandatory for Lex bots to function.
resource "aws_iam_role" "lex_role" {
  name                 = var.lexv2_bot_role_name// "${local.bot_name}-lex-role"
  assume_role_policy   = data.aws_iam_policy_document.lex_trust_relationship.json
  tags                 = var.tags
  max_session_duration = 43200
}

# ============================================================================
# Polly Permissions (Text-to-Speech)
# ============================================================================
# Enables Lex to convert text responses into speech using Amazon Polly.
# Required when voice responses are configured.

data "aws_iam_policy_document" "allow_synthesize_speech" {
  statement {
    sid    = "LexActions"
    effect = "Allow"
    actions = [
      "polly:SynthesizeSpeech"
    ]
    resources = [
      var.polly_arn
    ]
  }
}

resource "aws_iam_policy" "allow_synthesize_speech" {
  name   = "${local.bot_name}-allow-synthesize-speech-policy"
  policy = data.aws_iam_policy_document.allow_synthesize_speech.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "allow_synthesize_speech" {
  role       = aws_iam_role.lex_role.name
  policy_arn = aws_iam_policy.allow_synthesize_speech.arn
}

# ============================================================================
# CloudWatch Logging Permissions
# ============================================================================
# Allows Lex to:
# - Create log groups
# - Create log streams
# - Push logs to CloudWatch
#
# This is essential for debugging, monitoring, and production observability.
data "aws_iam_policy_document" "allow_lex_cloudwatch_logging" {
  statement {
    sid    = "AllowLexCloudWatchLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup"
    ]
    resources = [
      var.cloudwatch_log_group_arn
    ]
  }
}

resource "aws_iam_policy" "allow_lex_cloudwatch_logging" {
  name   = "${local.bot_name}-allow-lex-cloudwatch-logging-policy"
  policy = data.aws_iam_policy_document.allow_lex_cloudwatch_logging.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "allow_lex_cloudwatch_logging" {
  role       = aws_iam_role.lex_role.name
  policy_arn = aws_iam_policy.allow_lex_cloudwatch_logging.arn
}

# ============================================================================
# Lambda Invocation Permissions (Dynamic)
# ============================================================================
# Grants Lex permission to invoke Lambda functions used for:
# - Fulfillment code hooks
# - Validation logic
#
# This block is conditionally created ONLY if Lambda ARNs are provided.
# This keeps the module flexible and avoids unnecessary permissions.
data "aws_iam_policy_document" "allow_invoke_lambdas" {
  count = length(var.lambda_arns) > 0 ? 1 : 0

  statement {
    sid    = "AllowInvokeLambdas"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = values(var.lambda_arns)
  }
}

resource "aws_iam_policy" "allow_invoke_lambdas" {
  count  = length(var.lambda_arns) > 0 ? 1 : 0
  name   = "${local.bot_name}-allow-invoke-lambdas-policy"
  policy = data.aws_iam_policy_document.allow_invoke_lambdas[0].json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "allow_invoke_lambdas" {
  count      = length(var.lambda_arns) > 0 ? 1 : 0
  role       = aws_iam_role.lex_role.name
  policy_arn = aws_iam_policy.allow_invoke_lambdas[0].arn
}