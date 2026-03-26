# ============================================================================
# Lambda Permission for Lex Invocation (NEW)
# ============================================================================

# resource "aws_lambda_permission" "lex_invoke" {
#   for_each = local.lambda_map

#   statement_id  = "AllowLexInvoke-${each.key}"
#   action        = "lambda:InvokeFunction"
#   function_name = each.value
#   principal     = "lexv2.amazonaws.com"
# }

# resource "aws_lambda_permission" "lex_invoke" {
#   for_each = var.lambda_functions != null ? var.lambda_functions : {}

#   statement_id  = "AllowLexInvoke-${each.key}"
#   action        = "lambda:InvokeFunction"
#   function_name = each.value.function_name
#   principal     = "lex.amazonaws.com"
# }

# Allow Lex to invoke your Lambdas
# resource "aws_lambda_permission" "lex_invoke" {
#   for_each = var.lambda_functions   # static keys map from caller

#   statement_id  = "AllowLexInvoke-${each.key}"
#   action        = "lambda:InvokeFunction"

#   # Use the Lambda module output to get ARN at runtime
#   function_name = lookup(module.lambda.functions, each.key, null) != null ? module.lambda.functions[each.key].arn : ""

#   principal     = "lex.amazonaws.com"
# }

resource "aws_lambda_permission" "lex_invoke" {
  for_each = var.lambda_functions

  statement_id  = "AllowLexInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.arn
  principal     = "lex.amazonaws.com"
}