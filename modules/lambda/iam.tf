# data "aws_iam_policy_document" "lambda_assume_role" {
#   statement {
#     effect = "Allow"
#     principals {
#       type        = "Service"
#       identifiers = ["lambda.amazonaws.com"]
#     }
#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "lambda_role" {
#   name               = "${var.function_name}-role"
#   assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
#   tags               = var.tags
# }

# resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }
# -----------------------------------------------
# IAM Role for each Lambda
# -----------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  for_each = var.lambdas

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  for_each = var.lambdas

  name               = "${each.key}-role"                   # use each.key instead of var.function_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role[each.key].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  for_each = var.lambdas

  role       = aws_iam_role.lambda_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}