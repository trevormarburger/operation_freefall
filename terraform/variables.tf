variable "env" {
  type        = string
  description = "Environment (e.g. dev/qa/prod)."
  default     = "dev"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP Project ID."
  default     = "tm-personal-proj-1"
}

variable "AV_API_KEY" {
  type        = string
  description = "AlphaVantage API Key."
}

variable "SLACK_WEBHOOK_URL" {
  type        = string
  description = "Slack Webhook URL."
}
