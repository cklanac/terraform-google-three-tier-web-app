terraform {
  required_version = ">= 0.14"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.50"
    }
  }
}

provider "google" {
  credentials = file("~/gcp-service-account-keys/<SERVICE ACCOUNT>")
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}
