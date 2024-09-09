variable "kms_key_id" {
  type    = string
  default = ""
}

variable "slack_workspace_id" {
  type    = string
  default = ""
}

variable "slack_channel_id" {
  type    = string
  default = ""
}

variable "chatbot_role_permissions_boundary_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/aws-service-role/AWSChatbotServiceLinkedRolePolicy"
}