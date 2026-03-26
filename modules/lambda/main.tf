resource "aws_lambda_function" "this" {
  for_each = var.lambdas

  function_name = each.key
  description   = each.value.description

  role = aws_iam_role.lambda_role[each.key].arn

  handler = each.value.handler
  runtime = each.value.runtime

  ##########################################
  # CI/CD Artifact (S3 आधारित)
  ##########################################
  s3_bucket = var.lambda_artifacts_bucket
  s3_key    = each.value.s3_key

  # Optional but recommended for update detection
  source_code_hash = lookup(each.value, "source_code_hash", null)

  ##########################################
  # Performance
  ##########################################
  timeout     = each.value.timeout
  memory_size = each.value.memory_size

  publish = true

  ##########################################
  # Environment Variables
  ##########################################
  dynamic "environment" {
    for_each = (
      length(var.environment_variables) > 0 ||
      length(each.value.environment_variables) > 0
    ) ? [1] : []

    content {
      variables = merge(
        var.environment_variables,
        each.value.environment_variables
      )
    }
  }

  ##########################################
  # Optional VPC
  ##########################################
  dynamic "vpc_config" {
    for_each = (
      var.vpc_subnet_ids != null &&
      var.vpc_security_group_ids != null
    ) ? [1] : []

    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  ##########################################
  # Observability
  ##########################################
  tracing_config {
    mode = "Active"
  }

  ##########################################
  # Ensure log group exists first
  ##########################################
  depends_on = [
    var.lambda_log_group_arns
  ]

  ##########################################
  # Tags
  ##########################################
  tags = merge(
    var.tags,
    var.function_tags
  )

  ##########################################
  # Lifecycle Safety
  ##########################################
  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
  }
}

# ############################################
# # Locals
# ############################################
# locals {
#   build_dir = "${path.module}/.build"
# }

# ############################################
# # Ensure build directory exists
# ############################################
# resource "null_resource" "prepare_build_dir" {
#   provisioner "local-exec" {
#     command = "mkdir -p ${local.build_dir}"
#   }
# }

# ############################################
# # Build Lambdas (npm install + build)
# ############################################
# resource "null_resource" "build" {
#   for_each = var.lambdas

#   # ✅ Rebuild if ANY file changes
#   triggers = {
#     source_hash = sha256(join("", [
#       for f in fileset(each.value.path, "**") :
#       filesha256("${each.value.path}/${f}")
#     ]))
#   }

#   provisioner "local-exec" {
#     working_dir = each.value.path
#     command = <<EOT
#       echo "Building ${each.key}"
#       npm install
#       npm run build
#     EOT
#   }
# }

# ############################################
# # Lambda Function
# ############################################
# resource "aws_lambda_function" "this" {
#   for_each = var.lambdas

#   function_name = each.key
#   description   = each.value.description

#   role = aws_iam_role.lambda_role[each.key].arn

#   handler = each.value.handler
#   runtime = each.value.runtime

#   ##########################################
#   # Artifact from CI/CD
#   ##########################################
#   filename         = each.value.artifact_path
#   source_code_hash = filebase64sha256(each.value.artifact_path)

#   ##########################################
#   # Performance
#   ##########################################
#   timeout     = each.value.timeout
#   memory_size = each.value.memory_size

#   publish = true

#   ##########################################
#   # Environment Variables (merged)
#   ##########################################
#   dynamic "environment" {
#     for_each = (
#       length(var.environment_variables) > 0 ||
#       length(each.value.environment_variables) > 0
#     ) ? [1] : []

#     content {
#       variables = merge(
#         var.environment_variables,
#         each.value.environment_variables
#       )
#     }
#   }

#   ##########################################
#   # Optional VPC
#   ##########################################
#   dynamic "vpc_config" {
#     for_each = (
#       var.vpc_subnet_ids != null &&
#       var.vpc_security_group_ids != null
#     ) ? [1] : []

#     content {
#       subnet_ids         = var.vpc_subnet_ids
#       security_group_ids = var.vpc_security_group_ids
#     }
#   }

#   ##########################################
#   # Observability (X-Ray)
#   ##########################################
#   tracing_config {
#     mode = "Active"
#   }

#   ##########################################
#   # Logging dependency
#   ##########################################
#   depends_on = [
#     aws_cloudwatch_log_group.lambda
#   ]

#   ##########################################
#   # Tags
#   ##########################################
#   tags = merge(
#     var.tags,
#     var.function_tags
#   )

#   ##########################################
#   # Lifecycle Safety
#   ##########################################
#   lifecycle {
#     prevent_destroy       = true
#     create_before_destroy = true
#   }
# }
# ############################################
# # Package Lambdas (zip dist/)
# ############################################
# data "archive_file" "lambda_zip" {
#   for_each = var.lambdas

#   type        = "zip"
#   source_dir  = "${each.value.path}/dist"
#   output_path = "${local.build_dir}/${each.key}.zip"

#   # ✅ Ensure build dir exists before zipping
#   depends_on = [
#     null_resource.prepare_build_dir
#   ]
# }

# data "archive_file" "this" {
#   for_each = var.lambdas

#   type        = "zip"
#   source_dir  = "${each.value.path}/dist"
#   output_path = "${path.module}/.build/${each.key}.zip"
# }

# # ############################################
# # # Lambda Function
# # ############################################
# # resource "aws_lambda_function" "this" {
# #   for_each = var.lambdas

# #   function_name = each.key
# #   description   = each.value.description
# #   role          = aws_iam_role.lambda_role[each.key].arn   # 🔥 fixed

# #   handler = each.value.handler
# #   runtime = each.value.runtime

# #   # filename         = data.archive_file.this[each.key].output_path
# #   # source_code_hash = data.archive_file.this[each.key].output_base64sha256
# #   filename         = each.value.artifact_path
# #   source_code_hash = filebase64sha256(each.value.artifact_path)
# #   timeout     = each.value.timeout
# #   memory_size = each.value.memory_size

# #   publish = true

# #   dynamic "environment" {
# #     for_each = length(var.environment_variables) > 0 ? [1] : []
# #     content {
# #       variables = var.environment_variables
# #     }
# #   }

# #   dynamic "vpc_config" {
# #     for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [1] : []
# #     content {
# #       subnet_ids         = var.vpc_subnet_ids
# #       security_group_ids = var.vpc_security_group_ids
# #     }
# #   }

# #   tags = merge(var.tags, var.function_tags)

# #   lifecycle {
# #     prevent_destroy       = true
# #     create_before_destroy = true
# #   }
# # }
# # resource "aws_lambda_function" "this" {
# #   for_each = var.lambdas

# #   function_name = each.key
# #   description = each.value.description
# #   role          = aws_iam_role.lambda_role.arn

# #   handler = each.value.handler
# #   runtime = each.value.runtime

# #   filename         = data.archive_file.lambda_zip[each.key].output_path
# #   source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256

# #   timeout     = each.value.timeout
# #   memory_size = each.value.memory_size

# #   publish = true

# #   ##########################################
# #   # Environment Variables (safe)
# #   ##########################################
# #   dynamic "environment" {
# #     for_each = length(var.environment_variables) > 0 ? [1] : []
# #     content {
# #       variables = var.environment_variables
# #     }
# #   }

# #   ##########################################
# #   # Optional VPC Config
# #   ##########################################
# #   dynamic "vpc_config" {
# #     for_each = (
# #       var.vpc_subnet_ids != null &&
# #       var.vpc_security_group_ids != null
# #     ) ? [1] : []

# #     content {
# #       subnet_ids         = var.vpc_subnet_ids
# #       security_group_ids = var.vpc_security_group_ids
# #     }
# #   }

# #   ##########################################
# #   # Tags
# #   ##########################################
# #   tags = merge(
# #     var.tags,
# #     var.function_tags
# #   )

# #   ##########################################
# #   # Lifecycle
# #   ##########################################
# #   lifecycle {
# #     prevent_destroy       = true
# #     create_before_destroy = true
# #   }

# #   ##########################################
# #   # Ensure build happens before deploy
# #   ##########################################
# #   depends_on = [
# #     null_resource.build
# #   ]
# # }
# # # # data "archive_file" "this" {
# # # #   type = "zip"
# # # #   source_dir  = "${path.module}/../build/${var.function_name}"
# # # #   output_path = "${path.module}/../build/${var.function_name}.zip"
# # # # }
# # # data "archive_file" "this" {
# # #   type        = "zip"
# # #   source_dir  = "${path.module}/${var.function_name}/dist"
# # #   output_path = "${path.module}/../../build/claims_handler.zip"
# # # }
# # # # ============================================================================
# # # # AWS Lambda Function
# # # # ============================================================================
# # # # Creates an AWS Lambda function with optional IAM role, VPC, environment variables,
# # # # and CloudWatch log retention.
# # # #
# # # # Features:
# # # # - Deploy code from S3 or local file path
# # # # - Configurable runtime and handler
# # # # - Optional environment variables
# # # # - Optional VPC configuration
# # # # - Supports tagging and versioning
# # # # ============================================================================

# # # resource "aws_lambda_function" "this" {
# # #   function_name                  = var.function_name
# # #   description                    = var.description
# # #   role                           = aws_iam_role.lambda_role.arn
# # #   handler                        = var.handler
# # #   runtime                        = var.runtime
# # #   timeout                        = var.timeout
# # #   memory_size                    = var.memory_size
# # #   filename                       = data.archive_file.this.output_path
# # #   reserved_concurrent_executions = var.reserved_concurrent_executions
# # #   kms_key_arn                    = var.kms_key_arn
# # #   source_code_hash               = data.archive_file.this.output_base64sha256

# # #   # --------------------------------------------------------------------------
# # #   # Enable Versioning
# # #   # --------------------------------------------------------------------------
# # #   publish = true

# # #   dynamic "environment" {
# # #     for_each = length(keys(var.environment_variables)) == 0 ? [] : [true]
# # #     content {
# # #       variables = var.environment_variables
# # #     }
# # #   }

# # #   dynamic "vpc_config" {
# # #     for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
# # #     content {
# # #       subnet_ids         = var.vpc_subnet_ids
# # #       security_group_ids = var.vpc_security_group_ids
# # #     }
# # #   }

# # #   tags = merge(
# # #     var.tags,
# # #   var.function_tags)

# # #   lifecycle {
# # #     prevent_destroy       = true
# # #     create_before_destroy = true
# # #   }
# # # }

# # locals {
# #   build_dir = "${path.module}/.build"
# # }
# # resource "null_resource" "prepare_build_dir" {
# #   provisioner "local-exec" {
# #     command = "mkdir -p ${local.build_dir}"
# #   }
# # }

# # resource "null_resource" "build" {
# #   for_each = var.lambdas

# #   triggers = {
# #     path_hash = filesha256("${each.value.path}/package.json")
# #   }

# #   provisioner "local-exec" {
# #     working_dir = each.value.path
# #     command = <<EOT
# #       echo "Building ${each.key}"
# #       npm install
# #       npm run build
# #     EOT
# #   }
# # }

# # data "archive_file" "lambda_zip" {
# #   for_each = var.lambdas

# #   type        = "zip"
# #   source_dir  = "${each.value.path}/dist"
# #   output_path = "${local.build_dir}/${each.key}.zip"

# #   # ✅ UPDATED HERE
# #   depends_on = [
# #     null_resource.build,
# #     null_resource.prepare_build_dir
# #   ]
# # }

# # resource "aws_lambda_function" "this" {
# #   for_each = var.lambdas

# #   function_name = each.key
# #   role          = aws_iam_role.lambda_role.arn

# #   handler = each.value.handler
# #   runtime = each.value.runtime

# #   filename         = data.archive_file.lambda_zip[each.key].output_path
# #   source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256

# #   timeout     = each.value.timeout
# #   memory_size = each.value.memory_size

# #   publish = true

# #   dynamic "environment" {
# #   for_each = length(var.environment_variables) > 0 ? [1] : []
# #   content {
# #     variables = var.environment_variables
# #   }
# # }

# #   dynamic "vpc_config" {
# #     for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
# #     content {
# #       subnet_ids         = var.vpc_subnet_ids
# #       security_group_ids = var.vpc_security_group_ids
# #     }
# #   }

# #   tags = merge(
# #     var.tags,
# #   var.function_tags)

# #   lifecycle {
# #     prevent_destroy       = true
# #     create_before_destroy = true
# #   }
# # }

# resource "aws_lambda_function" "this" {
#   for_each = var.lambdas

#   function_name = each.key
#   description   = each.value.description

#   role = aws_iam_role.lambda_role[each.key].arn

#   handler = each.value.handler
#   runtime = each.value.runtime

#   ##########################################
#   # CI/CD Artifact
#   ##########################################
#   filename         = each.value.artifact_path
#   source_code_hash = filebase64sha256(each.value.artifact_path)

#   ##########################################
#   # Performance
#   ##########################################
#   timeout     = each.value.timeout
#   memory_size = each.value.memory_size

#   publish = true

#   ##########################################
#   # Environment Variables
#   ##########################################
#   dynamic "environment" {
#     for_each = (
#       length(var.environment_variables) > 0 ||
#       length(each.value.environment_variables) > 0
#     ) ? [1] : []

#     content {
#       variables = merge(
#         var.environment_variables,
#         each.value.environment_variables
#       )
#     }
#   }

#   ##########################################
#   # Optional VPC
#   ##########################################
#   dynamic "vpc_config" {
#     for_each = (
#       var.vpc_subnet_ids != null &&
#       var.vpc_security_group_ids != null
#     ) ? [1] : []

#     content {
#       subnet_ids         = var.vpc_subnet_ids
#       security_group_ids = var.vpc_security_group_ids
#     }
#   }

#   ##########################################
#   # Observability
#   ##########################################
#   tracing_config {
#     mode = "Active"
#   }

#   ##########################################
#   # Ensure log group exists first
#   ##########################################
#   depends_on = [
#     var.lambda_log_group_arns
#   ]

#   ##########################################
#   # Tags
#   ##########################################
#   tags = merge(
#     var.tags,
#     var.function_tags
#   )

#   lifecycle {
#     prevent_destroy       = true
#     create_before_destroy = true
#   }
# }