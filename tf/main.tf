terraform {
  required_version = "~> 0.10"

  backend "gcs" {
    bucket = "d2lh-state-prod"
    prefix = "terraform/state"
  }
}

locals {
  credentials_file_path = "${var.credentials_file_path}"
  project               = "dota-2-leaderboards-history"
}

provider "google" {
  version = "~> 2.5"

  # credentials = "${file(var.credentials_file_path)}"
  # project     = "dota-2-leaderboards-history"
  project = "${local.project}"

  credentials = "${file(local.credentials_file_path)}"
  region      = "us-central1"
  zone        = "us-central1-b"
}

provider "random" {
  version = "~> 2.0"
}

data "google_project" "project" {}

# App Engine enables Datastore
resource "google_app_engine_application" "app" {
  project     = "${data.google_project.project.project_id}"
  location_id = "us-west2"
}

# Must be precreated in the UI as it needs to be linked to a GitHub repository
resource "google_sourcerepo_repository" "functions-repo" {
  name = "github_chaosk_dota2-leaderboards-history"
}

module "function-player_records" {
  source      = "./modules/google_cloud_function_http"
  name        = "player_records"
  description = "API for retrieving player leaderboard records from the database"
  repo_name   = "${google_sourcerepo_repository.functions-repo.name}"
  repo_url    = "${google_sourcerepo_repository.functions-repo.url}"
}

module "function-snapshot_list" {
  source      = "./modules/google_cloud_function_http"
  name        = "snapshot_list"
  description = "API for retrieving snapshot list from the database"
  repo_name   = "${google_sourcerepo_repository.functions-repo.name}"
  repo_url    = "${google_sourcerepo_repository.functions-repo.url}"
}

module "function-snapshot_records" {
  source      = "./modules/google_cloud_function_http"
  name        = "snapshot_records"
  description = "API for retrieving snapshot records from the database"
  repo_name   = "${google_sourcerepo_repository.functions-repo.name}"
  repo_url    = "${google_sourcerepo_repository.functions-repo.url}"
}

resource "google_cloudbuild_trigger" "deploy-fetch-leaderboards-trigger" {
  description = "fetch-leaderboards push trigger"

  trigger_template {
    branch_name = "master"
    repo_name   = "${google_sourcerepo_repository.functions-repo.name}"
  }

  included_files = ["functions/fetch_leaderboards/**"]

  build {
    step {
      name = "gcr.io/cloud-builders/gcloud"

      args = [
        "functions",
        "deploy",
        "api",
        "--source",
        "${google_cloudfunctions_function.fetch-leaderboards-function.source_repository.0.url}",
        "--runtime",
        "${google_cloudfunctions_function.fetch-leaderboards-function.runtime}",
        "--timeout",
        "${google_cloudfunctions_function.fetch-leaderboards-function.timeout}",
        "--entry-point",
        "${google_cloudfunctions_function.fetch-leaderboards-function.entry_point}",
        "--memory",
        "${google_cloudfunctions_function.fetch-leaderboards-function.available_memory_mb}MB",
        "--trigger-topic",
        "${google_cloudfunctions_function.fetch-leaderboards-function.event_trigger.0.resource}",
      ]
    }
  }
}

resource "google_cloudfunctions_function" "fetch-leaderboards-function" {
  name                = "fetch-leaderboards"
  description         = "Fetch leaderboards from Dota 2 API"
  available_memory_mb = 128
  runtime             = "python37"

  source_repository {
    # ???
    url = "${replace(replace(google_sourcerepo_repository.functions-repo.url, "//p//", "/projects/"), "//r//", "/repos/")}/moveable-aliases/master/paths/functions/fetch_leaderboards"
  }

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "${google_pubsub_topic.fetch-leaderboards.name}"
  }

  timeout     = 40
  entry_point = "entrypoint"
}

# UI deployment
resource "google_storage_bucket" "ui" {
  name          = "leaderboards.dota2.ecksdee.tech"
  location      = "US-WEST1"
  storage_class = "REGIONAL"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "google_cloudbuild_trigger" "ui-deployment" {
  description = "UI push trigger"

  trigger_template {
    branch_name = "master"
    repo_name   = "${google_sourcerepo_repository.functions-repo.name}"
    dir         = "ui/"
  }

  included_files = ["ui/**"]

  build {
    step {
      name = "gcr.io/cloud-builders/npm"

      args = [
        "install",
      ]
    }

    step {
      name = "gcr.io/cloud-builders/npm"

      args = [
        "run",
        "build",
      ]
    }

    step {
      name = "gcr.io/cloud-builders/gsutil"

      args = [
        "-m",
        "cp",
        "-r",
        "public/*",
        "${google_storage_bucket.ui.url}",
      ]
    }
  }
}

# Setup Datastore index
module "datastore" {
  source      = "terraform-google-modules/cloud-datastore/google"
  credentials = "${local.credentials_file_path}"
  project     = "${data.google_project.project.project_id}"
  indexes     = "${file("index.yaml")}"
}

# Allow build service to access cloud functions
resource "google_project_iam_member" "cloud-build-service-account" {
  role   = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloud-build-cloud-functions" {
  role   = "roles/cloudfunctions.developer"
  member = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Create PubSub topic for fetch-leaderboards function
resource "google_pubsub_topic" "fetch-leaderboards" {
  name = "functions.fetch-leaderboards"
}

# Schedule fetching leaderboards every midnight GMT
resource "google_cloud_scheduler_job" "fetch-leaderboards-europe" {
  name        = "fetch-leaderboards-europe"
  description = "Execute fetch-leaderboards for europe region, every day"
  schedule    = "0 0 * * *"
  region      = "us-west2"

  pubsub_target {
    topic_name = "${google_pubsub_topic.fetch-leaderboards.id}"
    data       = "${base64encode("europe")}"
  }
}

resource "google_cloud_scheduler_job" "fetch-leaderboards-americas" {
  name        = "fetch-leaderboards-americas"
  description = "Execute fetch-leaderboards for americas region, every day"
  schedule    = "0 0 * * *"
  region      = "us-west2"

  pubsub_target {
    topic_name = "${google_pubsub_topic.fetch-leaderboards.id}"
    data       = "${base64encode("americas")}"
  }
}

resource "google_cloud_scheduler_job" "fetch-leaderboards-se_asia" {
  name        = "fetch-leaderboards-se_asia"
  description = "Execute fetch-leaderboards for se_asia region, every day"
  schedule    = "0 0 * * *"
  region      = "us-west2"

  pubsub_target {
    topic_name = "${google_pubsub_topic.fetch-leaderboards.id}"
    data       = "${base64encode("se_asia")}"
  }
}

resource "google_cloud_scheduler_job" "fetch-leaderboards-china" {
  name        = "fetch-leaderboards-china"
  description = "Execute fetch-leaderboards for china region, every day"
  schedule    = "0 0 * * *"
  region      = "us-west2"

  pubsub_target {
    topic_name = "${google_pubsub_topic.fetch-leaderboards.id}"
    data       = "${base64encode("china")}"
  }
}
