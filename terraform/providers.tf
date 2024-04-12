terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.24.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.gcp_project_id
  region  = "us-central1"
}