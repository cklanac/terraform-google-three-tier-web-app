variable "project_id" {
  type        = string
  description = "The project ID to deploy resources to."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Google Cloud region"
}

variable "zone" {
  type        = string
  default     = "us-central1-c"
  description = "Google Cloud region"
}
