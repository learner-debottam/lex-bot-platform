variable "name" {
  description = "Name of the CloudWatch Log Group"
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "Optional KMS key ARN for log encryption"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the CloudWatch Log Group"
  type        = map(string)
  default     = {}
}

variable "prevent_destroy" {
  description = "Whether to prevent accidental deletion (e.g., in prod)"
  type        = bool
  default     = false
}