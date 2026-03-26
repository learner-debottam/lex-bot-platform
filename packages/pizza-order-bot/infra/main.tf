locals {
  bot_config = jsondecode(file("${path.module}/../bot-config/pizza-order-config.json"))
  bot_name   = local.bot_config.name
  polly_arn  = "arn:aws:polly:${var.aws_region}:${var.aws_account_id}:lexicon/*"

}

module "logs" {
  source = "../../../modules/cloudwatch-log-group"

  name              = "/aws/lex/${local.bot_name}"
  retention_in_days = 30
  prevent_destroy   = var.environment == "prod"
}

module "lex" {
  source = "../../../modules/lexv2models"

  bot_config = local.bot_config

  cloudwatch_log_group_arn = module.logs.log_group_arn

  polly_arn = local.polly_arn
  
  lexv2_bot_role_name = "${var.aws_account_name}-${var.environment}-${local.bot_name}-lex-iam-role"
}