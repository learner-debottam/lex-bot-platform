# ============================================================================
# Outputs – CloudWatch Log Group
# ============================================================================

output "log_group_name" {
  description = "The name of the CloudWatch Log Group"
  value = coalesce(
    try(aws_cloudwatch_log_group.protected[0].name, null),
    try(aws_cloudwatch_log_group.unprotected[0].name, null)
  )
}

output "log_group_arn" {
  value = coalesce(
    try(aws_cloudwatch_log_group.protected[0].arn, null),
    try(aws_cloudwatch_log_group.unprotected[0].arn, null)
  )
}