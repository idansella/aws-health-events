variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for posting messages"
  type        = string
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel name or ID where notifications will be sent"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "aws-health-to-slack"
}

variable "mappings_file_path" {
  description = "Path to the YAML file containing account mappings (relative to module root). Defaults to account-mappings.yaml"
  type        = string
  default     = "account-mappings.yaml"
}

variable "account_application_mapping" {
  description = "DEPRECATED: Use account-mappings.yaml instead. Map of AWS account ID to application and environment. Only used if mappings_file_path is not found."
  type = map(object({
    application = string
    environment = string
  }))
  default = {}
}

variable "channel_routing" {
  description = "Optional override for channel routing. If not specified, reads from account-mappings.yaml or uses template: #aws-health-{application}-{environment}"
  type = map(map(string))
  default = {}
}

variable "slack_channel_template" {
  description = "Template for channel name when not specified in channel_routing. Use {application} and {environment} as placeholders"
  type        = string
  default     = "#aws-health-{application}-{environment}"
}


