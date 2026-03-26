# # ============================================================================
# # Outputs – Lambda Module
# # ============================================================================

# # Lambda function ARN
# output "lambda_function_arn" {
#   description = "ARN of the Lambda function"
#   value       = aws_lambda_function.this.arn
# }

# # Lambda function name
# output "lambda_function_name" {
#   description = "Name of the Lambda function"
#   value       = aws_lambda_function.this.function_name
# }

# # Lambda IAM Role ARN
# output "lambda_role_arn" {
#   value = { for k, v in aws_iam_role.lambda_role : k => v.arn }
# }

# # Lambda function version ARN
# output "lambda_version_arn" {
#   description = "Versioned ARN of the Lambda function"
#   value       = aws_lambda_function.this.arn
# }

# # Latest published version
# output "lambda_version" {
#   description = "Latest published Lambda version"
#   value       = aws_lambda_function.this.version
# }

# # Versioned ARN (IMPORTANT for Lex / integrations)
# output "lambda_qualified_arn" {
#   description = "Qualified ARN including version"
#   value       = aws_lambda_function.this.qualified_arn
# }

# output "functions" {
#   value = {
#     for k, v in aws_lambda_function.this :
#     k => {
#       function_name = v.function_name
#       arn           = v.arn
#     }
#   }
# }

############################################
# Outputs – Lambda Module
############################################

# Lambda function ARN (map of all functions)
output "lambda_function_arn" {
  description = "ARNs of all Lambda functions"
  value = { for k, v in aws_lambda_function.this : k => v.arn }
}

# Lambda function name
output "lambda_function_name" {
  description = "Names of all Lambda functions"
  value = { for k, v in aws_lambda_function.this : k => v.function_name }
}

# Lambda IAM Role ARN
output "lambda_role_arn" {
  description = "IAM Role ARNs for all Lambda functions"
  value = { for k, v in aws_iam_role.lambda_role : k => v.arn }
}

# Lambda function version ARN
output "lambda_version_arn" {
  description = "Versioned ARN of all Lambda functions"
  value = { for k, v in aws_lambda_function.this : k => v.arn }
}

# Latest published version
output "lambda_version" {
  description = "Latest published Lambda versions"
  value = { for k, v in aws_lambda_function.this : k => v.version }
}

# Versioned ARN (IMPORTANT for Lex / integrations)
output "lambda_qualified_arn" {
  description = "Qualified ARNs including version for all Lambda functions"
  value = { for k, v in aws_lambda_function.this : k => v.qualified_arn }
}

# Generic functions output
output "functions" {
  description = "Map of all Lambda functions (name + ARN)"
  value = {
    for k, v in aws_lambda_function.this : k => {
      function_name = v.function_name
      arn           = v.arn
    }
  }
}