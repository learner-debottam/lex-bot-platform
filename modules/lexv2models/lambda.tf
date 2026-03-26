# ============================================================================
# Lambda Permissions for AWS Lex
# ============================================================================
# Resource Summary Table:
# ----------------------------------------------------------------------------
# | Resource Type           | Name / Identifier       | Purpose & Notes                                  |
# |-------------------------|------------------------|--------------------------------------------------|
# | aws_lambda_permission   | this                   | Grants Lex permission to invoke Lambda functions |
#
# Notes:
# - Permissions are created dynamically for each Lambda function provided in var.lambda_functions.
# - statement_id ensures uniqueness per Lambda function.
# - principal is always lex.amazonaws.com to allow Lex to invoke the function.
# - Fine-grained permissions are preferred over broad managed policies.
# ============================================================================
resource "aws_lambda_permission" "this" {
  for_each = var.lambda_functions

  statement_id  = "AllowLexInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.arn
  principal     = "lex.amazonaws.com"
}