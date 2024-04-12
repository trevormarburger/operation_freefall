resource "google_storage_bucket" "bucket" {
  name     = "gcf-code-bucket-202404-11-${var.env}"
  location = "US"
}

resource "google_storage_bucket_object" "archive" {
  name   = "index.zip"
  bucket = google_storage_bucket.bucket.name
  source = "/home/runner/work/operation_freefall/operation_freefall/src/my_function.zip"
}

resource "google_pubsub_topic" "my_topic" {
  name = "operation-freefall-${var.env}"
}

resource "google_cloud_scheduler_job" "my_scheduler_job" {
  name        = "my-scheduler-job-${var.env}"
  description = "My Cloud Scheduler job to trigger Cloud Function"
  schedule    = "0 10 * * 1-5"
  time_zone    = "America/New_York"

  pubsub_target {
    topic_name = "projects/${var.gcp_project_id}/topics/${google_pubsub_topic.my_topic.name}-${var.env}"
    data       = ""
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
  trigger_http                 = false
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
}

# # IAM entry for a single user to invoke the function
# resource "google_cloudfunctions_function_iam_member" "invoker" {
#   project        = google_cloudfunctions_function.function.project
#   region         = google_cloudfunctions_function.function.region
#   cloud_function = google_cloudfunctions_function.function.name

#   role   = "roles/cloudfunctions.invoker"
#   member = "user:myFunctionInvoker@example.com"
# }
