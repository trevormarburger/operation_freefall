terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.24.0"
    }
  }

  backend "gcs" {
    bucket         = "state-bucket-20240412"
    prefix         = "terraform/state/operation_freefall/${var.env}"
    project        = var.gcp_project_id
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = "us-central1"
}