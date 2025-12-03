#!/bin/bash
# Terraform import script for existing resources
# Run this from the vibe-trade-terraform directory

PROJECT_ID="vibe-trade-475704"
REGION="us-central1"
FIRESTORE_LOCATION="nam5"

echo "Importing existing GCP resources into Terraform state..."

# 1. Import Project Services (APIs)
echo "Importing project services..."
terraform import 'google_project_service.required_apis["run.googleapis.com"]' "projects/${PROJECT_ID}/services/run.googleapis.com"
terraform import 'google_project_service.required_apis["artifactregistry.googleapis.com"]' "projects/${PROJECT_ID}/services/artifactregistry.googleapis.com"
terraform import 'google_project_service.required_apis["cloudbuild.googleapis.com"]' "projects/${PROJECT_ID}/services/cloudbuild.googleapis.com"
terraform import 'google_project_service.required_apis["firestore.googleapis.com"]' "projects/${PROJECT_ID}/services/firestore.googleapis.com"

# 2. Import Artifact Registry Repository
echo "Importing Artifact Registry repository..."
terraform import google_artifact_registry_repository.docker_repo "projects/${PROJECT_ID}/locations/${REGION}/repositories/vibe-trade-mcp"

# 3. Import Service Account
echo "Importing service account..."
SERVICE_ACCOUNT_EMAIL="vibe-trade-mcp-runner@${PROJECT_ID}.iam.gserviceaccount.com"
terraform import google_service_account.cloud_run_sa "projects/${PROJECT_ID}/serviceAccounts/${SERVICE_ACCOUNT_EMAIL}"

# 4. Import Firestore Database
echo "Importing Firestore database..."
terraform import google_firestore_database.strategy "projects/${PROJECT_ID}/databases/strategy"

# 5. Import IAM Member for Firestore
echo "Importing Firestore IAM member..."
terraform import google_project_iam_member.firestore_user "projects/${PROJECT_ID} roles/datastore.user serviceAccount:${SERVICE_ACCOUNT_EMAIL}"

# 6. Import Cloud Run Service
echo "Importing Cloud Run service..."
terraform import google_cloud_run_v2_service.mcp_server "projects/${PROJECT_ID}/locations/${REGION}/services/vibe-trade-mcp"

# 7. Import Cloud Run IAM Member (public access)
echo "Importing Cloud Run IAM member..."
terraform import google_cloud_run_service_iam_member.public_access "projects/${PROJECT_ID}/locations/${REGION}/services/vibe-trade-mcp roles/run.invoker allUsers"

echo ""
echo "✅ Import complete! Run 'terraform plan' to verify everything is in sync."

