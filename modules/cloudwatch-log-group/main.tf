# ============================================================================
# AWS CloudWatch Log Group
# ============================================================================
# Creates a CloudWatch Log Group with configurable retention and tagging.
#
# Features:
# - Supports custom naming (for Lambda, Lex, or application logs)
# - Configurable retention policy
# - Optional KMS encryption
# - Prevents accidental deletion (optional lifecycle)
#
# Common Use Cases:
# - Lambda logs → /aws/lambda/<function-name>
# - Lex logs    → /aws/lex/<bot-name>
# - App logs    → /custom/app/logs
# ============================================================================

resource "aws_cloudwatch_log_group" "protected" {
  count             = var.prevent_destroy ? 1 : 0
  name              = var.name
  retention_in_days = var.retention_in_days

  # Optional KMS encryption for log data
  kms_key_id = var.kms_key_id != null ? var.kms_key_id : null

  tags = var.tags

  # --------------------------------------------------------------------------
  # Lifecycle Protection (Optional)
  # --------------------------------------------------------------------------
  # Prevent accidental deletion in production environments
  #
  lifecycle {
    prevent_destroy = true
  }
}



# ============================================================================
# AWS CloudWatch Log Group (Unprotected)
# ============================================================================
# This resource creates a CloudWatch Log Group WITHOUT deletion protection.
#
# Behavior:
# - Created ONLY when `prevent_destroy = false`
# - Allows normal Terraform lifecycle (create/update/destroy)
#
# Why this exists:
# Since Terraform lifecycle rules cannot be dynamic, this resource acts as the
# alternative to the protected version when deletion protection is not needed.
#
# Recommended Usage:
# - Use for development and test environments
# - Allows easy teardown and recreation of infrastructure
#
# Example:
#   prevent_destroy = false → This resource is used
#   prevent_destroy = true  → This resource is skipped
#
# ⚠️ Warning:
# Logs in this group will be permanently deleted if the resource is destroyed.
# ============================================================================

resource "aws_cloudwatch_log_group" "unprotected" {
  count = var.prevent_destroy ? 0 : 1

  # Fully qualified log group name
  name = var.name

  # Log retention policy in days
  retention_in_days = var.retention_in_days

  # Optional KMS encryption for log data
  kms_key_id = var.kms_key_id != null ? var.kms_key_id : null

  # Standard resource tags
  tags = var.tags
}