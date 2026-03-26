# # variable "function_name" {
# #   description = "Name of the Lambda function"
# #   type        = string
# # }

# # variable "runtime" {
# #   description = "Lambda runtime (e.g., python3.11, nodejs22.x)"
# #   type        = string
# #   default     = "nodejs22.x"
# # }

# # variable "handler" {
# #   description = "Lambda handler (e.g., index.handler)"
# #   type        = string
# # }

# variable "description" {
#   description = "Description of the Lambda function"
#   type        = string
#   default     = "Managed by Terraform"
# }

# # variable "timeout" {
# #   description = "Lambda timeout in seconds"
# #   type        = number
# #   default     = 30
# # }

# # variable "memory_size" {
# #   description = "Lambda memory size in MB"
# #   type        = number
# #   default     = 128
# # }

# variable "environment_variables" {
#   description = "Map of environment variables"
#   type        = map(string)
#   default     = {}
# }

# variable "vpc_subnet_ids" {
#   description = "Optional list of VPC subnet IDs if Lambda needs VPC access"
#   type        = list(string)
#   default     = []
# }

# variable "vpc_security_group_ids" {
#   description = "Optional list of VPC security group IDs if Lambda needs VPC access"
#   type        = list(string)
#   default     = []
# }

# variable "tags" {
#   description = "Tags to apply to Lambda and related resources"
#   type        = map(string)
#   default     = {}
# }

# variable "prevent_destroy" {
#   description = "Whether to prevent accidental deletion of Lambda"
#   type        = bool
#   default     = false
# }

# variable "reserved_concurrent_executions" {
#   description = "The number of concurrent executions reserved for this Lambda function (-1 means unreserved)."
#   type        = number
#   default     = -1
# }

# variable "kms_key_arn" {
#   description = "KMS Key ARN used to encrypt Lambda environment variables."
#   type        = string
#   default     = null
# }

# variable "function_tags" {
#   description = "Additional tags specifically for the Lambda function (merged with global tags)."
#   type        = map(string)
#   default     = {}
# }

# variable "lambdas" {
#   description = "Map of Lambda functions"
#   type = map(object({
#     path        = string
#     handler     = string
#     runtime     = string
#     timeout     = optional(number, 30)
#     memory_size = optional(number, 512)
#     description = string
#   }))
# }

############################################
# Variables
############################################
variable "lambdas" {
  description = "Map of Lambda configurations"
  type = map(object({
    # description           = string
    # handler               = string
    # runtime               = string
    # timeout               = number
    # memory_size           = number
    # artifact_path         = string
    # environment_variables = optional(map(string), {})
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