import json
import os
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


def _get_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _select_channel(event: dict, default_channel: str) -> str:
    # Event top-level has the source account id
    account_id = event.get("account")
    # Some AWS Health examples include affectedAccount inside detail
    detail_account_id = (event.get("detail") or {}).get("affectedAccount")

    # Load account to application/environment mapping
    account_mapping_raw = os.getenv("ACCOUNT_APPLICATION_MAPPING", "{}")
    try:
        account_mapping = json.loads(account_mapping_raw) if account_mapping_raw else {}
    except json.JSONDecodeError:
        account_mapping = {}

    # Load channel routing (application -> environment -> channel)
    channel_routing_raw = os.getenv("CHANNEL_ROUTING", "{}")
    try:
        channel_routing = json.loads(channel_routing_raw) if channel_routing_raw else {}
    except json.JSONDecodeError:
        channel_routing = {}

    # Get channel template
    channel_template = os.getenv("SLACK_CHANNEL_TEMPLATE", "#aws-health-{application}-{environment}")

    # Try to find account in mapping
    for acc_id in [account_id, detail_account_id]:
        if acc_id and acc_id in account_mapping:
            app_info = account_mapping[acc_id]
            application = app_info.get("application", "").upper()
            environment = app_info.get("environment", "").lower()

            # Check if there's a specific channel routing for this app/env
            if application in channel_routing:
                env_channels = channel_routing[application]
                if environment in env_channels:
                    return env_channels[environment]

            # Use template to construct channel name
            channel = channel_template.replace("{application}", application).replace(
                "{environment}", environment
            )
            return channel

    return default_channel


def _build_slack_message(event: dict, channel: str) -> dict:
    detail = event.get("detail", {})
    description = (
        (detail.get("eventDescription") or [{"latestDescription": ""}])[0]
    ).get("latestDescription", "")
    event_arn = detail.get("eventArn", "")
    phd_url = (
        "https://phd.aws.amazon.com/phd/home?region=us-east-1#/event-log?eventID="
        + event_arn
        if event_arn
        else "https://phd.aws.amazon.com/phd/home"
    )

    blocks = [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f":helmet_with_white_cross: AWS Health notification\n\n*{description}*",
            },
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"<{phd_url}|Click here for details>",
            },
        },
    ]

    return {"channel": channel, "blocks": blocks}


def handler(event, _context):
    webhook_url = _get_env("SLACK_WEBHOOK_URL")
    default_channel = _get_env("SLACK_CHANNEL")
    channel = _select_channel(event, default_channel)

    payload = _build_slack_message(event, channel)
    data = json.dumps(payload).encode("utf-8")

    req = Request(
        webhook_url,
        data=data,
        headers={"content-type": "application/json"},
        method="POST",
    )

    try:
        with urlopen(req) as resp:
            resp.read()
        return {"status": "ok"}
    except HTTPError as e:
        return {"status": "error", "code": e.code, "reason": e.reason}
    except URLError as e:
        return {"status": "error", "reason": str(e.reason)}


