locals {
  # Load bot configuration
  bot_config = jsondecode(file("${path.module}/../bot-config/insurance-config.json"))
  bot_name   = local.bot_config.name

  # Namespace for resource naming
  namespace = "${var.aws_account_name}-${var.environment}-${local.bot_name}"

  # Polly Lexicon ARN
  polly_arn = "arn:aws:polly:${var.aws_region}:${var.aws_account_id}:lexicon/*"

  # Extract all intents across locales
  intents = flatten([
    for locale, locale_data in local.bot_config.locales : [
      for intent_name, intent in locale_data.intents : merge(intent, {
        intent_name = intent_name
        locale      = locale
      })
    ]
  ])

  # Filter intents that have a fulfillment Lambda
  lambda_intents = [
    for intent in local.intents : intent
    if lookup(intent, "fulfillment_lambda_name", null) != null
  ]

  # Build Lambda map with config and artifact info
  # lambdas = {
  #   for intent in local.lambda_intents : intent.fulfillment_lambda_name => {
  #     artifact_path        = "${path.module}/../../artifacts/${intent.fulfillment_lambda_name}.zip"
  #     handler              = "index.handler"
  #     runtime              = "nodejs24.x"
  #     timeout              = lookup(intent.lambda_config, "timeout_ms", 3000) / 1000
  #     memory_size          = 1024
  #     description          = intent.description
  #     environment_variables = {
  #       INTENT_NAME = intent.fulfillment_lambda_name
  #     }
  #   }
  # }

  lambdas = {
    for intent in local.lambda_intents : intent.fulfillment_lambda_name => {
      s3_key      = "${intent.fulfillment_lambda_name}.zip"
      handler     = "index.handler"
      runtime     = "nodejs24.x"
      timeout     = floor(lookup(intent.lambda_config, "timeout_ms", 3000) / 1000)
      memory_size = 1024
      description = intent.description

      environment_variables = {
        INTENT_NAME = intent.fulfillment_lambda_name
      }
    }
  }

  # List of Lambda keys (names)
  //lambda_keys = keys(local.lambdas)

  # Lex Lambda map for module input
  # lex_lambda_keys = {
  #   for k in local.lambda_keys : k => {
  #     function_name = k
  #     # add extra attributes if Lex module expects them
  #   }
  # }
}

# ============================================================================
# ────────────────────────────── CLOUDWATCH LOG GROUPS ──────────────────────────────
# ============================================================================

# Lex logs (single log group)
module "lex_logs" {
  source            = "../../../modules/cloudwatch-log-group"
  name              = "/aws/lex/${local.bot_name}"
  retention_in_days = 30
  prevent_destroy   = var.environment == "prod"
}

# Lambda logs (dynamic log groups for each Lambda)
module "lambda_logs" {
  source   = "../../../modules/cloudwatch-log-group"
  for_each = local.lambdas

  name              = "/aws/lambda/${each.key}"
  retention_in_days = 30
  prevent_destroy   = var.environment == "prod"
}

# ============================================================================
# ────────────────────────────── LAMBDAS ──────────────────────────────
# ============================================================================

module "lambda" {
  source                  = "../../../modules/lambda"
  lambdas                 = local.lambdas
  prevent_destroy         = var.environment == "prod"
  lambda_artifacts_bucket = var.lambda_artifacts_bucket # ✅ add this

  # Map each Lambda to its CloudWatch log group ARN
  lambda_log_group_arns = {
    for k, v in module.lambda_logs : k => v.log_group_arn
  }
}

# ============================================================================
# ────────────────────────────── LEX BOT ──────────────────────────────
# ============================================================================

module "lex" {
  source = "../../../modules/lexv2models"

  bot_config = local.bot_config

  # Provide Lambda function info for Lex
  lambda_functions = {
    for k, v in module.lambda.functions : k => {
      function_name = v.function_name
      arn           = v.arn
    }
  }

  cloudwatch_log_group_arn = module.lex_logs.log_group_arn
  polly_arn                = local.polly_arn
  lexv2_bot_role_name      = "${local.namespace}-lex-iam-role"

  depends_on = [module.lambda] # Ensure Lambdas exist first
}