terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.34"
    }
  }
}

provider "aws" {
  region = local.region
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

## SNS Topic

resource "aws_sns_topic" "chatbot" {
  count = var.enabled ? 1 : 0

  name              = var.sns_topic_name
  display_name      = "SNS topic for AWS Chatbot"
  kms_master_key_id = var.kms_key_id
  policy            = data.aws_iam_policy_document.sns_chatbot[0].json
}

data "aws_iam_policy_document" "sns_chatbot" {
  count = var.enabled ? 1 : 0

  statement {
    sid = "GrantPublishToChatbotSupportedServices"

    actions   = ["sns:Publish"]
    resources = ["arn:aws:sns:${local.region}:${local.account_id}:${var.sns_topic_name}"]

    principals {
      type = "Service"
      identifiers = [
        "cloudwatch.amazonaws.com",
        "events.amazonaws.com",
      ]
    }
  }
}

## Slack Channel Configuration

resource "aws_cloudformation_stack" "slack_channel_config" {
  count = var.enabled ? 1 : 0

  name = "chatbot-slack-channel-config-${var.chatbot_config_name}"
  template_body = jsonencode(yamldecode(templatefile("${path.module}/cfn-chatbot-slack.yaml.tpl", {
    config_name        = var.chatbot_config_name
    iam_role_arn       = aws_iam_role.chatbot[0].arn
    slack_workspace_id = var.slack_workspace_id
    slack_channel_id   = var.slack_channel_id
    log_level          = var.log_level
    sns_topic_arn      = aws_sns_topic.chatbot[0].arn
  })))
}

## Chatbot IAM Role

resource "aws_iam_role" "chatbot" {
  count = var.enabled ? 1 : 0

  name                 = "AWSChatbotRole-${var.chatbot_config_name}"
  assume_role_policy   = data.aws_iam_policy_document.chatbot_assume_role[0].json
  permissions_boundary = var.chatbot_role_permissions_boundary_policy_arn
}

data "aws_iam_policy_document" "chatbot_assume_role" {
  count = var.enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "chatbot_notifications" {
  count = var.enabled && var.chatbot_role_allow_notifications ? 1 : 0

  name   = "NotificationsOnly"
  role   = aws_iam_role.chatbot[0].id
  policy = data.aws_iam_policy_document.chatbot_notifications_only[0].json
}

data "aws_iam_policy_document" "chatbot_notifications_only" {
  count = var.enabled ? 1 : 0

  statement {
    actions = [
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "chatbot_lambda_invoke" {
  count = var.enabled && var.chatbot_role_allow_labmda_invoke ? 1 : 0

  name   = "LambdaInvoke"
  role   = aws_iam_role.chatbot[0].id
  policy = data.aws_iam_policy_document.chatbot_lambda_invoke[0].json
}

data "aws_iam_policy_document" "chatbot_lambda_invoke" {
  count = var.enabled ? 1 : 0

  statement {
    actions = [
      "lambda:invokeAsync",
      "lambda:invokeFunction",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "chatbot_support_access" {
  count = var.enabled && var.chatbot_role_allow_support_access ? 1 : 0

  role       = aws_iam_role.chatbot[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSSupportAccess"
}

resource "aws_iam_role_policy_attachment" "chatbot_read_only_access" {
  count = var.enabled && var.chatbot_role_allow_read_only_access ? 1 : 0

  role       = aws_iam_role.chatbot[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_cloudwatch_event_rule" "health" {
  count = var.enabled ? 1 : 0

  name          = "chatbot-health-alerts"
  description   = "Send AWS Health events to AWS Chatbot"
  event_pattern = <<-EOT
    {
      "source": [
        "aws.health"
      ]
    }
    EOT
}

resource "aws_cloudwatch_event_target" "health" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.health[0].name
  target_id = "chatbot-health-alerts"
  arn       = aws_sns_topic.chatbot[0].arn
}

resource "aws_cloudwatch_event_rule" "rds" {
  count = var.enabled ? 1 : 0

  name          = "chatbot-rds-alerts"
  description   = "Send AWS RDS events to AWS Chatbot"
  event_pattern = <<-EOT
    {
      "source": [
        "aws.rds"
      ]
    }
    EOT
}

resource "aws_cloudwatch_event_target" "rds" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.rds[0].name
  target_id = "chatbot-rds-alerts"
  arn       = aws_sns_topic.chatbot[0].arn
}

resource "aws_cloudwatch_event_rule" "elasticache" {
  count = var.enabled ? 1 : 0

  name          = "chatbot-elasticache-alerts"
  description   = "Send AWS ElastiCache events to AWS Chatbot"
  event_pattern = <<-EOT
    {
      "source": [
        "aws.elasticache"
      ]
    }
    EOT
}

resource "aws_cloudwatch_event_target" "elasticache" {
  count = var.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.elasticache[0].name
  target_id = "chatbot-elasticache-alerts"
  arn       = aws_sns_topic.chatbot[0].arn
}