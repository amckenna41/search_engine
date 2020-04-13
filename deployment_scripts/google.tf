#Terraform Deployment Script for Google Cloud
#https://www.terraform.io/docs/providers/google/index.html

# Configure the Google Provider, credentials and the region
provider "google" {
  project     = "my-project-id"
  credentials = "${file("credentials.json)}"
  region      = "europe-west1"
}

#set up new project to hold all the resources and infastrucutre for QSE
resource "google_project" "qse" {
  name       = "QSE"
  project_id = "qse-project-id"

}

#create google cloud data storage bucket for the spider indexer, enable versioning of bucket
resource "google_storage_bucket" "data-store" {
  name     = "spider_indexer"
  location = "EU"

  versioning {
    enabled = true

  }
}

#create google cloud data storage bucket for the front-end, enable versioning of bucket
#Enable bucket for static web hosting to host the front-end of the system
resource "google_storage_bucket" "data-store" {
  name     = "front_end"
  location = "EU"

  versioning {
      enabled = true
  }

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

#Create google source repository for spider indexer repo
resource "google_sourcerepo_repository" "spider_indexer" {
  name = "spider_indexer_repo"
}

#create google source repository for front-end repo
resource "google_sourcerepo_repository" "front_end" {
  name = "front_end_repo"
}

#create cloud build trigger that sets the spider indexer source repository (master branch) as a trigger for the build project
resource "google_cloudbuild_trigger" "cloudbuild-spider_indexer" {
  trigger_template {
    branch_name = "master"
    repo_name   = "spider_indexer_repo"
  }

  filename = "cloudbuild.yaml"                                    #cloudbuild.yml contains the relevant commands to compile source code from repo and run any tests etc
}                                                                 #similar to AWS buildspec.yml & Azure azure-pipelines.yml

#create cloud build trigger that sets the front-end source repository (master branch) as a trigger for the build project
resource "google_cloudbuild_trigger" "cloudbuild-front-end" {
  trigger_template {
    branch_name = "master"
    repo_name   = "front_end_repoend"
  }

  filename = "cloudbuild.yaml"                                    #cloudbuild.yml contains the relevant commands to compile source code from repo and run any tests etc
}                                                                 #similar to AWS buildspec.yml & Azure azure-pipelines.yml


#create cloud composer environment for spider_indexer ci pipeline
resource "google_composer_environment" "composer_spider_indexer" {
  name   = "spider_indexer_composer"
  region = "europe-west1"
}

#create cloud composer environment for front-end ci pipeline
resource "google_composer_environment" "composer_front-end" {
  name   = "front_end_composer"
  region = "europe-west1"
}

#role for ci pipeline resources and tools inclduing repository, build and composer
resource "google_project_iam_custom_role" "ci-role" {
  role_id     = "ci-role"
  title       = "Ci Role"
  description = "Role for code pipeline resources and tools"
  permissions = ["sourcerepo.respositories.list", "sourcerepo.respositories.create", "sourcerepo.respositories.delete",
                 "composer.pipelines.list", "composer.pipelines.create", "composer.pipelines.delete",
                 "cloudbuild.trigger.list", "cloudbuild.trigger.create", "cloudbuild.trigger.delete"]

}

#Google cloud pubsub created for pipeline which sends email to any subscribers of pubsub topic
resource "google_pubsub_topic" "pipeline-pubsub-topic" {
  name = "pipeline-topic"
}

#subscription for pubsub topic for the pipelines
resource "google_pubsub_subscription" "pipeline-pubsub-subscription" {
  name  = "pipeline_subscription"
  topic = google_pubsub_topic.pipeline-topic.name

  ack_deadline_seconds = 20

}

#cloud function created for spider indexer function
resource "google_cloudfunctions_function" "spider_indexer" {
  name        = "spider_indexer_func"
  description = "Google Cloud Function for spider indexer"
  runtime     = "Python 3.7"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.spider_indexer.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  entry_point           = "GET"
}

#api to execute spider indexer function
resource "google_endpoints_service" "openapi_service" {
  service_name   = "spider_indexer.endpoints.qse.cloud.goog"      #api URL
  project        = "qse"
  openapi_config = file("openapi_spec.yml")             #OpenAPI REST API integration
}

#api to search spider indexer output in database
resource "google_endpoints_service" "openapi_service" {
  service_name   = "search_api.endpoints.qse.cloud.goog"
  project        = "qse"
  openapi_config = file("openapi_spec.yml")
}

#api to search ads database
resource "google_endpoints_service" "openapi_service" {
  service_name   = "ads.endpoints.qse.cloud.goog"
  project        = "qse"
  openapi_config = file("openapi_spec.yml")
}

#create spanner instance which the spanner database is hosted on, spider indexer database instance
resource "google_spanner_instance" "spider_instance" {
  config       = "regional-europe-west1"
  display_name = "spider_indexer"
}

#create database which is hosted on instance. Database for spider indexer output from function
resource "google_spanner_database" "database" {
  instance = google_spanner_instance.main.spider_instance.name
  name     = "spider_indexer"
  ddl = [
    "CREATE TABLE spider_indexer (Title STRING NOT NULL, H1 STRING NOT NULL, H2 STRING NOT NULL, Text STRING NOT NULL) PRIMARY KEY(Title)"
  ]
}         #SQL code to run on database creation, creating columns


#create spanner instance which hosts ads database
resource "google_spanner_instance" "ads_instance" {
  config       = "regional-europe-west1"
  display_name = "ads"
}

#create spanner database to hold ads info
resource "google_spanner_database" "database" {
  instance = google_spanner_instance.ads_instance.name
  name     = "ads"
  ddl = [
    "CREATE TABLE ads (Title STRING NOT NULL, Description STRING NOT NULL, Description2 STRING NOT NULL) PRIMARY KEY(Title)"
  ]
}

#Google cloud pubsub created for databases which sends email to any subscribers of pubsub topic
resource "google_pubsub_topic" "databases-pubsub-topic" {
  name = "databases-topic"
}

#subscription for pubsub topic for the databases
resource "google_pubsub_subscription" "databases-pubsub-subscription" {
  name  = "databases_subscription"
  topic = google_pubsub_topic.databases-topic.name

  ack_deadline_seconds = 20

}


#role for spanner databases - all access allowed to create, edit and delete databases
resource "google_project_iam_custom_role" "spanner_role" {
  role_id     = "spanner_role"
  title       = "Spanner Role"
  description = "Role for code pipeline resources and tools"
  permissions = ["spanner.tables.*]
}

#IAM policy for cloud function
resource "google_cloudfunctions_function_iam_policy" "editor" {
  project = "${google_cloudfunctions_function.spider_indexer_func.qse}"
  region = "${google_cloudfunctions_function.spider_indexer_func.region}"
  cloud_function = "${google_cloudfunctions_function.spider_indexer_func.name}"
  policy_data = "${data.google_iam_policy.admin.policy_data}"
}

#**Google ClousSearch not available to implement via Terraform scripts**# 
