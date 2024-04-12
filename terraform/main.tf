resource "google_storage_bucket" "bucket" {
  name     = "gcf-code-bucket-202404-11-${var.env}"
  location = "US"
}

data "archive_file" "function_archive" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.root}/function.zip"
}

resource "google_storage_bucket_object" "archive" {
  name                = format("%s#%s", "function.zip", data.archive_file.function_archive.output_md5)
  bucket              = google_storage_bucket.bucket.name
  source              = data.archive_file.function_archive.output_path
  content_disposition = "attachment"
  content_encoding    = "gzip"
  content_type        = "application/zip"
}

resource "google_pubsub_topic" "my_topic" {
  name = "operation-freefall-${var.env}"
}

resource "google_cloud_scheduler_job" "my_scheduler_job" {
  name        = "my-scheduler-job-${var.env}"
  description = "Cloud Scheduler job to trigger Cloud Function for Operation Freefall."
  schedule    = "0 10 * * 1-5"
  time_zone    = "America/New_York"

  pubsub_target {
    topic_name = "projects/${var.gcp_project_id}/topics/${google_pubsub_topic.my_topic.name}-${var.env}"
    data       = base64encode("{\"mesage\": \"run\"}")
  }

  retry_config {
    retry_count        = 3
    max_retry_duration = "60s"
  }
}

resource "google_cloudfunctions_function" "function" {
  name        = "operation-freefall-${var.env}"
  description = "Operation Freefall Function"
  runtime     = "python39"

  available_memory_mb          = 512
  source_archive_bucket        = google_storage_bucket.bucket.name
  source_archive_object        = google_storage_bucket_object.archive.name
  timeout                      = 60
  entry_point                  = "main"

  labels = {
    environment = var.env
  }

  environment_variables = {
    AV_API_KEY        = var.AV_API_KEY
    SLACK_WEBHOOK_URL = var.SLACK_WEBHOOK_URL
  }

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.my_topic.name
  }

  depends_on = [
    google_cloud_scheduler_job.my_scheduler_job,
    google_storage_bucket_object.archive
  ]
}
