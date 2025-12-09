## AWS Health to Slack (Terraform)

This Terraform configuration deploys an AWS Lambda function and an EventBridge rule to forward AWS Health events to a Slack channel, following the setup described by Tutorials Dojo: [Real-time AWS Health Dashboard updates via Slack notifications](https://tutorialsdojo.com/real-time-aws-health-dashboard-updates-via-slack-notifications/).

### Architecture Diagram

A visual flow diagram is available in `aws-health-to-slack-flow.drawio`. To view it:
1. Open [draw.io](https://app.diagrams.net/) (or use the VS Code draw.io extension)
2. Open the `aws-health-to-slack-flow.drawio` file
3. The diagram shows the complete flow from AWS Health events to Slack channels

### Prerequisites
- Slack Incoming Webhook URL
- Terraform >= 1.5
- AWS credentials with permissions to create IAM, Lambda, EventBridge, and CloudWatch Logs

### GitOps Approach

This module uses a **GitOps approach** for account mappings:

1. **Account mappings are defined in `account-mappings.yaml`** - A single source of truth for all account-to-application/environment mappings
2. **Terraform automatically detects the current AWS account ID** - Uses `aws_caller_identity` data source
3. **Automatic lookup** - The current account ID is used to lookup the application/environment from the YAML file
4. **No per-account configuration needed** - Each account deployment uses the same Terraform code and automatically knows its mapping

### Inputs
- `aws_region` (default: `us-east-1`)
- `slack_webhook_url` (sensitive) - Slack Incoming Webhook URL
- `slack_channel` - **Default Slack channel** - Used for accounts not specified in `account-mappings.yaml`
- `lambda_function_name` (default: `aws-health-to-slack`)
- `mappings_file_path` (default: `"account-mappings.yaml"`) - Path to the YAML file containing account mappings
- `account_application_mapping` (optional, deprecated) - Fallback if YAML file is not found
- `channel_routing` (optional) - Override channel names per application/environment (can also be defined in YAML)
- `slack_channel_template` (default: `"#aws-health-{application}-{environment}"`) - Template for channel names

### Usage

This module supports multi-account installations organized by application. Each application can have 2 accounts (dev, prod) or 4 accounts (dev, int, stg, prod).

#### Step 1: Define Account Mappings

Edit `account-mappings.yaml` to define your account mappings:

```yaml
accounts:
  "111111111111":
    application: "DUP"
    environment: "dev"
  
  "222222222222":
    application: "DUP"
    environment: "prod"
  
  "333333333333":
    application: "DPS"
    environment: "dev"
  # ... more accounts
```

#### Step 2: Configure Terraform Variables

Create a `terraform.tfvars` file:

```hcl
aws_region        = "us-east-1"
slack_webhook_url = "https://hooks.slack.com/services/XXX/YYY/ZZZ"
slack_channel     = "#infra-alerts"  # Default for unmapped accounts
```

**That's it!** No need to specify account mappings in tfvars - they're read from `account-mappings.yaml`.

#### Step 3: Deploy

Deploy the same Terraform code to each AWS account:

```bash
terraform init
terraform apply -auto-approve
```

Terraform will:
1. Automatically detect the current AWS account ID
2. Look it up in `account-mappings.yaml`
3. Configure the Lambda with the appropriate application/environment mapping

**Note:** Deploy this module in each AWS account using the same code and `account-mappings.yaml` file. Each account will automatically use its own mapping based on the account ID. **If an account is not specified in `account-mappings.yaml`, all notifications from that account will go to the default `slack_channel`.**

### Testing
Use the Lambda console Test with an event similar to the tutorial’s example. The function reads `event.detail.eventDescription[0].latestDescription` and posts to Slack with a link to the AWS Personal Health Dashboard event.

### Notes
- **GitOps approach**: All account mappings are managed in `account-mappings.yaml` - a single source of truth that can be version controlled and reviewed via pull requests
- **Multi-account deployment**: Deploy the same Terraform code to each AWS account. Each account automatically knows its mapping from the YAML file
- **Automatic account detection**: Terraform uses `aws_caller_identity` to get the current account ID and looks it up in the YAML file
- EventBridge rule filters on source `aws.health` and detail-type `AWS Health Event`
- Lambda runtime: Python 3.11
- **Channel routing**: The Lambda looks up the account ID in the mappings (from YAML), then routes to the appropriate channel based on application and environment. **If the account is not found in the mapping, it uses the default `slack_channel`** (e.g., `#infra-alerts`)
- **Channel naming**: By default, channels follow the pattern `#aws-health-{application}-{environment}` (e.g., `#aws-health-DUP-dev`, `#aws-health-DPS-prod`). Override with `channel_routing` in YAML or tfvars if needed


