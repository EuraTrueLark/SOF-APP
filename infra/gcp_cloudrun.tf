# Steri-Tek Smart SOF Infrastructure - GCP Cloud Run
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6"
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (staging/production)"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "deployment_strategy" {
  description = "Deployment strategy (rolling/blue-green)"
  type        = string
  default     = "rolling"
}

variable "rollback" {
  description = "Trigger rollback to previous version"
  type        = bool
  default     = false
}

# Data sources
data "google_project" "project" {
  project_id = var.project_id
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "sql.googleapis.com",
    "storage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "secretmanager.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = true
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "sof-postgres-${var.environment}"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  settings {
    tier = var.environment == "production" ? "db-standard-2" : "db-standard-1"

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = var.environment == "production" ? 30 : 7
      }
    }

    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc.self_link
      authorized_networks {
        name  = "cloud-run"
        value = "0.0.0.0/0"
      }
    }

    maintenance_window {
      day  = 7
      hour = 4
    }
  }

  deletion_protection = var.environment == "production"

  depends_on = [google_project_service.required_apis]
}

# Database
resource "google_sql_database" "sof_db" {
  name     = "sof_${var.environment}"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

# Database user
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_sql_user" "sof_user" {
  name     = "sof_user"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
  project  = var.project_id
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "sof-vpc-${var.environment}"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "subnet" {
  name          = "sof-subnet-${var.environment}"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.self_link
  project       = var.project_id
}

# Cloud Storage Buckets
resource "google_storage_bucket" "sof_files" {
  name     = "sof-files-${var.project_id}-${var.environment}"
  location = var.region
  project  = var.project_id

  lifecycle_rule {
    condition {
      age = 90
      matches_prefix = ["drafts/"]
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 2555  # 7 years
      matches_prefix = ["completed/"]
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "sof_backups" {
  name     = "sof-backups-${var.project_id}-${var.environment}"
  location = var.region
  project  = var.project_id

  lifecycle_rule {
    condition {
      age = 2555  # 7 years
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
}

# Secret Manager secrets
resource "google_secret_manager_secret" "db_connection" {
  secret_id = "sof-db-connection-${var.environment}"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_connection" {
  secret = google_secret_manager_secret.db_connection.id
  secret_data = jsonencode({
    host     = google_sql_database_instance.postgres.private_ip_address
    port     = 5432
    database = google_sql_database.sof_db.name
    username = google_sql_user.sof_user.name
    password = random_password.db_password.result
  })
}

# Service definitions
locals {
  services = {
    api-gateway = {
      image = "ghcr.io/${var.project_id}/sof-api-gateway"
      port  = 8000
      env_vars = {
        ENVIRONMENT = var.environment
        PROJECT_ID  = var.project_id
      }
      memory = "1Gi"
      cpu    = "1000m"
    }
    sof-service = {
      image = "ghcr.io/${var.project_id}/sof-service"
      port  = 8001
      env_vars = {
        ENVIRONMENT = var.environment
        PROJECT_ID  = var.project_id
      }
      memory = "2Gi"
      cpu    = "1000m"
    }
    auth-service = {
      image = "ghcr.io/${var.project_id}/sof-auth-service"
      port  = 8002
      env_vars = {
        ENVIRONMENT = var.environment
        PROJECT_ID  = var.project_id
      }
      memory = "512Mi"
      cpu    = "500m"
    }
    file-service = {
      image = "ghcr.io/${var.project_id}/sof-file-service"
      port  = 8003
      env_vars = {
        ENVIRONMENT = var.environment
        PROJECT_ID  = var.project_id
        BUCKET_NAME = google_storage_bucket.sof_files.name
      }
      memory = "1Gi"
      cpu    = "500m"
    }
    audit-service = {
      image = "ghcr.io/${var.project_id}/sof-audit-service"
      port  = 8004
      env_vars = {
        ENVIRONMENT = var.environment
        PROJECT_ID  = var.project_id
      }
      memory = "1Gi"
      cpu    = "500m"
    }
    frontend = {
      image = "ghcr.io/${var.project_id}/sof-frontend"
      port  = 3000
      env_vars = {
        ENVIRONMENT     = var.environment
        API_BASE_URL    = "https://api-gateway-${var.environment}-${random_id.suffix.hex}-uc.a.run.app"
        NEXT_PUBLIC_ENV = var.environment
      }
      memory = "512Mi"
      cpu    = "500m"
    }
  }
}

# Random suffix for unique service names
resource "random_id" "suffix" {
  byte_length = 4
}

# Cloud Run services
resource "google_cloud_run_v2_service" "services" {
  for_each = local.services

  name     = "${each.key}-${var.environment}-${random_id.suffix.hex}"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.cloud_run.email

    containers {
      image = "${each.value.image}:${var.image_tag}"
      
      ports {
        container_port = each.value.port
      }

      resources {
        limits = {
          memory = each.value.memory
          cpu    = each.value.cpu
        }
      }

      dynamic "env" {
        for_each = each.value.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Database connection secret
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_connection.secret_id
            version = "latest"
          }
        }
      }

      # Health check
      startup_probe {
        http_get {
          path = "/health"
          port = each.value.port
        }
        initial_delay_seconds = 30
        timeout_seconds       = 10
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = each.value.port
        }
        timeout_seconds   = 5
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    scaling {
      min_instance_count = var.environment == "production" ? 2 : 0
      max_instance_count = var.environment == "production" ? 10 : 3
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc.name
        subnetwork = google_compute_subnetwork.subnet.name
      }
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [google_project_service.required_apis]
}

# Service Account for Cloud Run
resource "google_service_account" "cloud_run" {
  account_id   = "sof-cloud-run-${var.environment}"
  display_name = "SOF Cloud Run Service Account"
  project      = var.project_id
}

# IAM bindings for service account
resource "google_project_iam_member" "cloud_run_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# IAM policy for Cloud Run invoker
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  for_each = google_cloud_run_v2_service.services

  location = each.value.location
  project  = each.value.project
  service  = each.value.name
  
  policy_data = data.google_iam_policy.noauth.policy_data
}

# Load Balancer (for production)
resource "google_compute_global_address" "lb_ip" {
  count   = var.environment == "production" ? 1 : 0
  name    = "sof-lb-ip-${var.environment}"
  project = var.project_id
}

# Monitoring and Alerting
resource "google_monitoring_notification_channel" "email" {
  count        = var.environment == "production" ? 1 : 0
  display_name = "SOF Alert Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = "devops@steri-tek.com"
  }
}

resource "google_monitoring_alert_policy" "high_error_rate" {
  count        = var.environment == "production" ? 1 : 0
  display_name = "SOF High Error Rate"
  project      = var.project_id

  conditions {
    display_name = "Error rate > 5%"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = 0.05

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Outputs
output "service_urls" {
  description = "URLs of deployed Cloud Run services"
  value = {
    for k, v in google_cloud_run_v2_service.services : k => v.uri
  }
}

output "database_connection" {
  description = "Database connection details"
  value = {
    host     = google_sql_database_instance.postgres.private_ip_address
    database = google_sql_database.sof_db.name
  }
  sensitive = true
}

output "storage_buckets" {
  description = "Storage bucket names"
  value = {
    files   = google_storage_bucket.sof_files.name
    backups = google_storage_bucket.sof_backups.name
  }
}
