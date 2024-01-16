# Contains Cloud Run related resources:
# - google_cloud_run_service for both api and fe
# - google_service_account
# - google_project_iam_member
# - Service accounts and IAM roles and  policies
# - google_cloud_run_service_iam_member)

# Cloud Run FE service needs to communicate with the Cloud Run BE service over HTTP requests. Cloud Run BE service, in turn, needs to access the database such as connecting to a Cloud SQL instance.

# Both Cloud Run services (FE and BE) use the google_service_account.runsa service account to authenticate and authorize their actions within Google Cloud Platform. The permissions needed by the Cloud Run services are determined by the roles attached to this service account (google_service_account.runsa).
# The roles are defined in var.run_roles_list, which is a list of IAM roles that will be assigned to the service account.

# The google_project_iam_member resource is used to assign necessary IAM roles to your google_service_account.runsa. These roles should provide just enough permissions for the services to perform their required tasks, adhering to the principle of least privilege.

# Creates a dedicated service account for Cloud Run services, providing a specific identity for running applications and facilitating fine-grained access control.
resource "google_service_account" "runsa" {
  project      = var.project_id
  account_id   = "${var.deployment_name}-run-sa"
  display_name = "Service Account for Cloud Run"
}

# Assigns specific IAM roles to the Cloud Run service account, as defined in var.run_roles_list, enhancing security by granting only the necessary permissions for operation.
resource "google_project_iam_member" "allrun" {
  for_each = toset(var.run_roles_list)
  project  = data.google_project.project.number
  role     = each.key
  member   = "serviceAccount:${google_service_account.runsa.email}"
}


# Deploys the backend API as a serverless container on Cloud Run, configured with environment variables to connect to the Redis cache and Cloud SQL database. Includes autoscaling and VPC access settings.
resource "google_cloud_run_service" "api" {
  name     = "${var.deployment_name}-api"
  provider = google-beta
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = google_service_account.runsa.email
      containers {
        image = local.api_image
        env {
          name  = "redis_host"
          value = google_redis_instance.main.host
        }
        env {
          name  = "db_host"
          value = google_sql_database_instance.main.ip_address[0].ip_address
        }
        env {
          name  = "db_user"
          value = google_service_account.runsa.email
        }
        env {
          name  = "db_conn"
          value = google_sql_database_instance.main.connection_name
        }
        env {
          name  = "db_name"
          value = "todo"
        }
        env {
          name  = "redis_port"
          value = "6379"
        }

      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"        = "8"
        "run.googleapis.com/cloudsql-instances"   = google_sql_database_instance.main.connection_name
        "run.googleapis.com/client-name"          = "terraform"
        "run.googleapis.com/vpc-access-egress"    = "all"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.main.id
      }
      labels = {
        "run.googleapis.com/startupProbeType" = "Default"
      }
    }
  }
  metadata {
    labels = var.labels
  }
  autogenerate_revision_name = true
  depends_on = [
    google_sql_user.main,
    google_sql_database.database
  ]
}

# Deploys the frontend service as a serverless container on Cloud Run, configured to connect to the backend API. Includes autoscaling and port configuration.
resource "google_cloud_run_service" "fe" {
  name     = "${var.deployment_name}-fe"
  location = var.region
  project  = var.project_id

  template {
    spec {
      service_account_name = google_service_account.runsa.email
      containers {
        image = local.fe_image
        ports {
          container_port = 80
        }
        env {
          name  = "ENDPOINT"
          value = google_cloud_run_service.api.status[0].url
        }
      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "8"
      }
      labels = {
        "run.googleapis.com/startupProbeType" = "Default"
      }
    }
  }
  metadata {
    labels = var.labels
  }
}

# Configures IAM policy for the backend API Cloud Run service to allow unauthenticated access from all users.
resource "google_cloud_run_service_iam_member" "noauth_api" {
  location = google_cloud_run_service.api.location
  project  = google_cloud_run_service.api.project
  service  = google_cloud_run_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Configures IAM policy for the frontend Cloud Run service to allow unauthenticated access from all users.
resource "google_cloud_run_service_iam_member" "noauth_fe" {
  location = google_cloud_run_service.fe.location
  project  = google_cloud_run_service.fe.project
  service  = google_cloud_run_service.fe.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
