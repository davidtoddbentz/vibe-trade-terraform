terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "firestore.googleapis.com",
    # Uncomment if using Cloud Armor rate limiting:
    # "compute.googleapis.com",      # For load balancer
    # "cloudarmor.googleapis.com",    # For Cloud Armor rate limiting
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Artifact Registry repository for Docker images - MCP
resource "google_artifact_registry_repository" "docker_repo_mcp" {
  location      = var.region
  repository_id = "vibe-trade-mcp"
  description   = "Docker repository for Vibe Trade MCP server"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Artifact Registry repository for Docker images - Agent
resource "google_artifact_registry_repository" "docker_repo_agent" {
  location      = var.region
  repository_id = "vibe-trade-agent"
  description   = "Docker repository for Vibe Trade Agent"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Artifact Registry repository for Docker images - API
resource "google_artifact_registry_repository" "docker_repo_api" {
  location      = var.region
  repository_id = "vibe-trade-api"
  description   = "Docker repository for Vibe Trade API"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Artifact Registry repository for Python packages
resource "google_artifact_registry_repository" "python_repo" {
  location      = var.region
  repository_id = "vibe-trade-python"
  description   = "Python package repository for shared libraries"
  format        = "PYTHON"

  depends_on = [google_project_service.required_apis]
}

# Service account for Cloud Run service
resource "google_service_account" "cloud_run_sa" {
  account_id   = "vibe-trade-mcp-runner"
  display_name = "Vibe Trade MCP Cloud Run Service Account"
  description  = "Service account for running the MCP server on Cloud Run"
}

# Firestore database (Native mode)
resource "google_firestore_database" "strategy" {
  project     = var.project_id
  name        = "strategy"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.required_apis]
}

# Grant Firestore access to Cloud Run service account
resource "google_project_iam_member" "firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"

  depends_on = [google_service_account.cloud_run_sa]
}

# Cloud Run service
resource "google_cloud_run_v2_service" "mcp_server" {
  name     = "vibe-trade-mcp"
  location = var.region

  template {
    service_account = google_service_account.cloud_run_sa.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_mcp.repository_id}/vibe-trade-mcp:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "FIRESTORE_DATABASE"
        value = google_firestore_database.strategy.name
      }
      env {
        name  = "MCP_AUTH_TOKEN"
        value = var.mcp_auth_token
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.required_apis,
    google_artifact_registry_repository.docker_repo_mcp,
    google_firestore_database.strategy,
  ]
}

# Service account for Agent Cloud Run service
resource "google_service_account" "agent_cloud_run_sa" {
  account_id   = "vibe-trade-agent-runner"
  display_name = "Vibe Trade Agent Cloud Run Service Account"
  description  = "Service account for running the agent on Cloud Run"
}

# Service account for API Cloud Run service
resource "google_service_account" "api_cloud_run_sa" {
  account_id   = "vibe-trade-api-runner"
  display_name = "Vibe Trade API Cloud Run Service Account"
  description  = "Service account for running the API on Cloud Run"
}

# Grant Firestore access to API Cloud Run service account
resource "google_project_iam_member" "api_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.api_cloud_run_sa.email}"

  depends_on = [google_service_account.api_cloud_run_sa]
}

# Grant Artifact Registry read access to API Cloud Run service account
resource "google_artifact_registry_repository_iam_member" "api_python_reader" {
  location   = var.region
  repository = google_artifact_registry_repository.python_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.api_cloud_run_sa.email}"

  depends_on = [
    google_service_account.api_cloud_run_sa,
    google_artifact_registry_repository.python_repo,
  ]
}

# Cloud Run service for Agent
resource "google_cloud_run_v2_service" "agent" {
  name     = "vibe-trade-agent"
  location = var.region

  template {
    service_account = google_service_account.agent_cloud_run_sa.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_agent.repository_id}/vibe-trade-agent:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "OPENAI_API_KEY"
        value = var.openai_api_key
      }
      env {
        name  = "LANGSMITH_API_KEY"
        value = var.langsmith_api_key
      }
      env {
        name  = "MCP_SERVER_URL"
        value = "${google_cloud_run_v2_service.mcp_server.uri}/mcp"
      }
      # MCP_AUTH_TOKEN is optional - agent will use service account identity token
      # when running in Cloud Run (automatic service-to-service auth)
      # Can still be set explicitly if needed
      env {
        name  = "MCP_AUTH_TOKEN"
        value = var.mcp_auth_token
      }
      env {
        name  = "OPENAI_MODEL"
        value = var.openai_model
      }
      env {
        name  = "MAX_TOKENS"
        value = var.max_tokens
      }
      env {
        name  = "MAX_ITERATIONS"
        value = var.max_iterations
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.required_apis,
    google_artifact_registry_repository.docker_repo_agent,
    google_cloud_run_v2_service.mcp_server,
  ]
}

# Make agent service publicly accessible
# Rate limiting will be handled by Cloud Armor when enabled (see commented section below)
resource "google_cloud_run_service_iam_member" "agent_public_access" {
  location = google_cloud_run_v2_service.agent.location
  service  = google_cloud_run_v2_service.agent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# OPTIONAL: Cloud Armor rate limiting with load balancer
# Uncomment this section to use infrastructure-level rate limiting
# Requires: domain name, DNS setup, SSL certificate provisioning
# See RATE_LIMITING.md for details
#
# This will:
# - Allow authenticated users (with MCP_AUTH_TOKEN) - no rate limit
# - Rate limit unauthenticated users to 15 requests/hour per IP
#
# resource "google_compute_security_policy" "agent_rate_limit" {
#   name        = "vibe-trade-agent-rate-limit"
#   description = "Rate limiting: 15 requests/hour per IP (unauthenticated), unlimited for authenticated"
#
#   # Rule 1: Allow authenticated users (no rate limit)
#   # Checks for Authorization: Bearer <MCP_AUTH_TOKEN> header
#   rule {
#     action   = "allow"
#     priority = "1000"
#     match {
#       expr {
#         expression = "has(request.headers['authorization']) && request.headers['authorization'].startsWith('Bearer ') && request.headers['authorization'].replace('Bearer ', '') == '${var.mcp_auth_token}'"
#       }
#     }
#     description = "Allow authenticated users - no rate limit"
#   }
#
#   # Rule 2: Rate limit unauthenticated users
#   rule {
#     action   = "throttle"
#     priority = "2000"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["*"]
#       }
#     }
#     rate_limit_options {
#       conform_action = "allow"
#       exceed_action  = "deny(429)"
#       enforce_on_key = "IP"
#       rate_limit_threshold {
#         count        = 15
#         interval_sec = 3600
#       }
#     }
#     description = "Rate limit: 15 requests per hour per IP (unauthenticated only)"
#   }
#
#   # Default rule: allow all (fallback)
#   rule {
#     action   = "allow"
#     priority = "2147483647"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["*"]
#       }
#     }
#     description = "Default allow rule"
#   }
# }
#
# resource "google_compute_region_network_endpoint_group" "agent_neg" {
#   name                  = "vibe-trade-agent-neg"
#   network_endpoint_type = "SERVERLESS"
#   region                = var.region
#   cloud_run {
#     service = google_cloud_run_v2_service.agent.name
#   }
# }
#
# resource "google_compute_backend_service" "agent_backend" {
#   name                  = "vibe-trade-agent-backend"
#   description           = "Backend service for agent with rate limiting"
#   protocol              = "HTTP"
#   port_name             = "http"
#   timeout_sec           = 30
#   enable_cdn            = false
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#
#   backend {
#     group = google_compute_region_network_endpoint_group.agent_neg.id
#   }
#
#   security_policy = google_compute_security_policy.agent_rate_limit.id
#
#   log_config {
#     enable      = true
#     sample_rate = 1.0
#   }
# }

# # URL map for load balancer
# resource "google_compute_url_map" "agent_url_map" {
#   name            = "vibe-trade-agent-url-map"
#   description     = "URL map for agent service"
#   default_service = google_compute_backend_service.agent_backend.id
# }

# # HTTP(S) proxy for load balancer
# resource "google_compute_target_https_proxy" "agent_https_proxy" {
#   name             = "vibe-trade-agent-https-proxy"
#   url_map          = google_compute_url_map.agent_url_map.id
#   ssl_certificates = [google_compute_managed_ssl_certificate.agent_cert.id]
# }

# # Managed SSL certificate
# resource "google_compute_managed_ssl_certificate" "agent_cert" {
#   name = "vibe-trade-agent-ssl-cert"
#
#   managed {
#     domains = [var.agent_domain] # e.g., "agent.vibe-trade.com"
#   }
# }

# # Global forwarding rule (load balancer)
# resource "google_compute_global_forwarding_rule" "agent_forwarding_rule" {
#   name                  = "vibe-trade-agent-forwarding-rule"
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   port_range            = "443"
#   target                = google_compute_target_https_proxy.agent_https_proxy.id
# }

# # Make agent service accessible only to load balancer (not public)
# # Remove public access since load balancer will handle it
# # resource "google_cloud_run_service_iam_member" "agent_public_access" {
# #   location = google_cloud_run_v2_service.agent.location
# #   service  = google_cloud_run_v2_service.agent.name
# #   role     = "roles/run.invoker"
# #   member   = "allUsers"
# # }

# # Allow load balancer to invoke agent service
# resource "google_cloud_run_service_iam_member" "agent_lb_access" {
#   location = google_cloud_run_v2_service.agent.location
#   service  = google_cloud_run_v2_service.agent.name
#   role     = "roles/run.invoker"
#   member   = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
# }

# data "google_project" "project" {
#   project_id = var.project_id
# }

# Cloud Run service for API
resource "google_cloud_run_v2_service" "api" {
  name     = "vibe-trade-api"
  location = var.region

  template {
    service_account = google_service_account.api_cloud_run_sa.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_api.repository_id}/vibe-trade-api:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "FIRESTORE_DATABASE"
        value = google_firestore_database.strategy.name
      }
      env {
        name  = "NEXTAUTH_SECRET"
        value = var.nextauth_secret
      }
      env {
        name  = "CORS_ORIGINS"
        value = "*" # TODO: Restrict to UI domain in production
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.required_apis,
    google_artifact_registry_repository.docker_repo_api,
    google_firestore_database.strategy,
    google_project_iam_member.api_firestore_user,
  ]
}

# Make API service publicly accessible (authentication handled by JWT middleware)
resource "google_cloud_run_service_iam_member" "api_public_access" {
  location = google_cloud_run_v2_service.api.location
  service  = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Make MCP service publicly accessible (authentication handled by app-level middleware)
# TODO: After MVP, remove public access and make MCP private (only accessible by agent service)
# Service-to-service auth will use identity tokens from service account credentials
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.mcp_server.location
  service  = google_cloud_run_v2_service.mcp_server.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Artifact Registry repository for Docker images - UI
resource "google_artifact_registry_repository" "docker_repo_ui" {
  location      = var.region
  repository_id = "vibe-trade-ui"
  description   = "Docker repository for Vibe Trade UI"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Service account for UI Cloud Run service
resource "google_service_account" "ui_cloud_run_sa" {
  account_id   = "vibe-trade-ui-runner"
  display_name = "Vibe Trade UI Cloud Run Service Account"
  description  = "Service account for running the UI on Cloud Run"
}

# Cloud Run service for UI
resource "google_cloud_run_v2_service" "ui" {
  name     = "vibe-trade-ui"
  location = var.region

  template {
    service_account = google_service_account.ui_cloud_run_sa.email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_ui.repository_id}/vibe-trade-ui:latest"

      ports {
        container_port = 8080
      }

      # Note: PORT is automatically set by Cloud Run - don't set it manually
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      # Firebase Admin SDK uses Application Default Credentials on GCP
      # No need to set FIREBASE_SERVICE_ACCOUNT_KEY when running on Cloud Run
      # Optional: Set FIREBASE_SERVICE_ACCOUNT_KEY if you need explicit service account
      # env {
      #   name  = "FIREBASE_SERVICE_ACCOUNT_KEY"
      #   value = var.firebase_service_account_key
      # }
      env {
        name  = "SNAPTRADE_CLIENT_ID"
        value = var.snaptrade_client_id
      }
      env {
        name  = "SNAPTRADE_CONSUMER_KEY"
        value = var.snaptrade_consumer_key
      }
      # Optional environment variables - uncomment if needed
      # env {
      #   name  = "NEXT_PUBLIC_FINNHUB_API_KEY"
      #   value = var.finnhub_api_key
      # }
      # env {
      #   name  = "NEXT_PUBLIC_LOGODEV_TOKEN"
      #   value = var.logodev_token
      # }
      # Note: NEXT_PUBLIC_* variables must be set at BUILD TIME (as Docker build args)
      # They are baked into the JavaScript bundle during `next build`
      # See Makefile for how to pass these during docker build

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.required_apis,
    google_artifact_registry_repository.docker_repo_ui,
  ]
}

# Make UI service publicly accessible
resource "google_cloud_run_service_iam_member" "ui_public_access" {
  location = google_cloud_run_v2_service.ui.location
  service  = google_cloud_run_v2_service.ui.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

