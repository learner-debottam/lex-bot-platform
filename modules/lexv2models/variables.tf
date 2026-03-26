variable "bot_config" {
  description = "Decoded JSON bot configuration"
  type        = any
}

variable "lambda_arns" {
  description = "Optional map of Lambda ARNs keyed by logical names used in bot_config (e.g., fulfillment_lambda_name)"
  type        = map(string)
  default     = {}
}

variable "polly_arn" {
  description = "ARN of polly"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_arn" {
  description = "ARN of CloudWatch Log Group"
  type        = string
  default     = null
}
variable "lambda_functions" {
  type = map(object({
    function_name = string
    arn           = string
  }))
  description = "Map of Lambda function objects for Lex intents"
}
# variable "lambda_functions" {
#   description = "Map of Lambda functions created by lambda module"
#   type = map(object({
#     function_name = string
#     arn           = string
#   }))
#   default = {}
# }

variable "lexv2_bot_role_name" {
  description = "ARN of CloudWatch Log Group"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_version" {
  type    = bool
  default = false
}