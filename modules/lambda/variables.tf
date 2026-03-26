# ============================================================================
# Variables – Lambda Module
# ============================================================================
# Variable Summary Table:
# ----------------------------------------------------------------------------
# | Variable Name              | Type / Default                   | Description                                                   |
# |----------------------------|---------------------------------|---------------------------------------------------------------|
# | lambdas                     | map(object)                     | Map of Lambda function configurations (handler, runtime, etc.)|
# | environment_variables       | map(string)                     | Global environment variables applied to all Lambda functions |
# | vpc_subnet_ids              | list(string) / null             | Optional VPC subnet IDs for Lambda functions                 |
# | vpc_security_group_ids      | list(string) / null             | Optional VPC security group IDs for Lambda functions         |
# | tags                        | map(string)                     | Tags applied to all resources                                  |
# | function_tags               | map(string)                     | Tags applied specifically to Lambda functions                |
# | prevent_destroy             | bool / false                    | Enable prevent_destroy for critical environments             |
# | lambda_log_group_arns       | map(string) / {}                | Map of Lambda log group ARNs                                  |
# | lambda_artifacts_bucket     | string                          | S3 bucket containing Lambda deployment artifacts             |
#
# Notes:
# - `lambdas` object supports optional fields: `environment_variables`, `source_code_hash`.
# - `vpc_subnet_ids` and `vpc_security_group_ids` allow Lambda to run in private subnets.
# - `prevent_destroy` provides an extra safeguard against accidental deletion.
# - `lambda_artifacts_bucket` must exist and contain all Lambda deployment packages.
# ============================================================================

variable "lambdas" {
  description = "Map of Lambda configurations"
  type = map(object({
    s3_key      = string
    handler     = string
    runtime     = string
    timeout     = number
    memory_size = number
    description = string
    environment_variables = optional(map(string), {})
    source_code_hash      = optional(string)
  }))
}

variable "environment_variables" {
  description = "Global environment variables applied to all Lambdas"
  type        = map(string)
  default     = {}
}

variable "vpc_subnet_ids" {
  type    = list(string)
  default = null
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "function_tags" {
  type    = map(string)
  default = {}
}

variable "prevent_destroy" {
  description = "Enable prevent_destroy for critical environments"
  type        = bool
  default     = false
}

variable "lambda_log_group_arns" {
  description = "Map of Lambda log group ARNs"
  type        = map(string)
  default     = {}
}

variable "lambda_artifacts_bucket" {
  description = "S3 bucket where Lambda artifacts are stored"
  type        = string
}