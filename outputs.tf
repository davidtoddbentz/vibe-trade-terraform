output "service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.mcp_server.uri
}

output "mcp_endpoint" {
  description = "MCP endpoint URL"
  value       = "${google_cloud_run_v2_service.mcp_server.uri}/mcp"
}

output "artifact_registry_url_mcp" {
  description = "Artifact Registry repository URL for MCP images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_mcp.repository_id}"
}

output "artifact_registry_url_agent" {
  description = "Artifact Registry repository URL for Agent images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_agent.repository_id}"
}

output "service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.mcp_server.name
}

output "service_location" {
  description = "Cloud Run service location"
  value       = google_cloud_run_v2_service.mcp_server.location
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "firestore_location" {
  description = "Firestore database location"
  value       = google_firestore_database.strategy.location_id
}

output "firestore_database_name" {
  description = "Firestore database name"
  value       = google_firestore_database.strategy.name
}

output "agent_service_url" {
  description = "URL of the Agent Cloud Run service"
  value       = google_cloud_run_v2_service.agent.uri
}

output "agent_service_name" {
  description = "Agent Cloud Run service name"
  value       = google_cloud_run_v2_service.agent.name
}

output "api_service_url" {
  description = "URL of the API Cloud Run service"
  value       = google_cloud_run_v2_service.api.uri
}

output "api_service_name" {
  description = "API Cloud Run service name"
  value       = google_cloud_run_v2_service.api.name
}

output "artifact_registry_url_api" {
  description = "Artifact Registry repository URL for API images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_api.repository_id}"
}

output "python_package_repo_url" {
  description = "Artifact Registry Python package repository URL"
  value       = "${var.region}-python.pkg.dev/${var.project_id}/${google_artifact_registry_repository.python_repo.repository_id}/simple/"
}

output "ui_service_url" {
  description = "URL of the UI Cloud Run service"
  value       = google_cloud_run_v2_service.ui.uri
}

output "ui_service_name" {
  description = "UI Cloud Run service name"
  value       = google_cloud_run_v2_service.ui.name
}

output "artifact_registry_url_ui" {
  description = "Artifact Registry repository URL for UI images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo_ui.repository_id}"
}

# Firebase configuration outputs (for reference/build scripts)
output "firebase_api_key" {
  description = "Firebase API key (for build-time use)"
  value       = var.firebase_api_key
  sensitive   = true
}

output "firebase_auth_domain" {
  description = "Firebase Auth domain (for build-time use)"
  value       = var.firebase_auth_domain
}

output "firebase_project_id" {
  description = "Firebase Project ID (for build-time use)"
  value       = var.firebase_project_id
}

