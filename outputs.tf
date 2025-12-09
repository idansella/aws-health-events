output "lambda_function_name" {
  value       = aws_lambda_function.this.function_name
  description = "Deployed Lambda function name"
}

output "event_rule_arn" {
  value       = aws_cloudwatch_event_rule.aws_health.arn
  description = "EventBridge rule ARN for AWS Health"
}

output "current_account_mapping" {
  value       = local.current_account_mapping
  description = "Application and environment mapping for the current AWS account (from account-mappings.yaml)"
}


