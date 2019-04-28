resource "google_cloudbuild_trigger" "trigger" {
  description = "${var.name} push trigger"

  trigger_template {
    branch_name = "master"
    repo_name   = "${var.repo_name}"
  }

  included_files = ["functions/${var.name}/**"]

  build {
    step {
      name = "gcr.io/cloud-builders/gcloud"

      args = [
        "functions",
        "deploy",
        "${var.name}",
        "--source",
        "${google_cloudfunctions_function.function.source_repository.0.url}",
        "--runtime",
        "${google_cloudfunctions_function.function.runtime}",
        "--timeout",
        "${google_cloudfunctions_function.function.timeout}",
        "--entry-point",
        "${google_cloudfunctions_function.function.entry_point}",
        "--memory",
        "${google_cloudfunctions_function.function.available_memory_mb}MB",
        "--trigger-http",
      ]
    }
  }
}

resource "google_cloudfunctions_function" "function" {
  name                = "${var.name}"
  description         = "${var.description}"
  available_memory_mb = "${var.available_memory_mb}"
  runtime             = "${var.runtime}"

  source_repository {
    # ???
    url = "${replace(replace(var.repo_url, "//p//", "/projects/"), "//r//", "/repos/")}/moveable-aliases/master/paths/functions/${var.name}"
  }

  trigger_http = true
  timeout      = 5
  entry_point  = "entrypoint"
}
