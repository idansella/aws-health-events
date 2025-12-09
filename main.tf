data "aws_caller_identity" "current" {}

# Read account mappings from YAML file (GitOps approach)
locals {
  mappings_file_path = "${path.module}/${var.mappings_file_path}"
  mappings_file_exists = fileexists(local.mappings_file_path)
  mappings_file = local.mappings_file_exists ? file(local.mappings_file_path) : yamlencode({ accounts = {}, channel_routing = {} })
  mappings_data = try(yamldecode(local.mappings_file), { accounts = {}, channel_routing = {} })
  
  # Get current account ID from AWS context
  current_account_id = data.aws_caller_identity.current.account_id
  
  # Build account_application_mapping for Lambda
  # Priority: YAML file > variable override > empty
  account_application_mapping = local.mappings_file_exists && length(local.mappings_data.accounts) > 0 ? {
    for account_id, mapping in local.mappings_data.accounts : account_id => {
      application = mapping.application
      environment = mapping.environment
    }
  } : var.account_application_mapping
  
  # Get channel_routing: variable override > YAML > empty
  channel_routing = length(var.channel_routing) > 0 ? var.channel_routing : (
    local.mappings_file_exists && length(local.mappings_data.channel_routing) > 0 ? local.mappings_data.channel_routing : {}
  )
  
  # Current account's application/environment (for outputs/validation)
  current_account_mapping = lookup(local.account_application_mapping, local.current_account_id, null)
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.terraform/build/lambda.zip"
}

resource "aws_iam_role" "lambda_exec_role" {
  name               = "${var.lambda_function_name}-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action   = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_logs_policy" {
  name = "${var.lambda_function_name}-logs"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "this" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL            = var.slack_webhook_url
      SLACK_CHANNEL                = var.slack_channel
      ACCOUNT_APPLICATION_MAPPING  = jsonencode(local.account_application_mapping)
      CHANNEL_ROUTING              = jsonencode(local.channel_routing)
      SLACK_CHANNEL_TEMPLATE       = var.slack_channel_template
    }
  }

  depends_on = [aws_iam_role_policy.lambda_logs_policy]
}

resource "aws_cloudwatch_event_rule" "aws_health" {
  name        = "aws-health-events"
  description = "Capture AWS Health events"

  event_pattern = jsonencode({
    source      = ["aws.health"],
    "detail-type" = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.aws_health.name
  target_id = "lambda"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.aws_health.arn
}


