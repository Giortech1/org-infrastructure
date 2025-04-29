#!/bin/bash
# Setup script for consistent project configuration
# Usage: ./setup-project.sh <project-id> <environment>

set -e  # Exit on any error

PROJECT_ID=${1:-"giortech-dev-project"}
ENVIRONMENT=${2:-"dev"}
REGION=${3:-"us-central1"}

echo "Setting up project $PROJECT_ID ($ENVIRONMENT)..."

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  secretmanager.googleapis.com \
  cloudresourcemanager.googleapis.com \
  dns.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  billingbudgets.googleapis.com \
  --project=${PROJECT_ID}

# Create service account if it doesn't exist
echo "Setting up service account..."
if ! gcloud iam service-accounts describe github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com --project=${PROJECT_ID} &>/dev/null; then
  gcloud iam service-accounts create github-actions-sa \
    --display-name="GitHub Actions Service Account" \
    --project=${PROJECT_ID}
fi

# Grant necessary roles
echo "Granting roles to service account..."
SERVICE_ACCOUNT="github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"
ROLES=(
  "roles/run.admin"
  "roles/storage.admin"
  "roles/iam.serviceAccountUser"
  "roles/secretmanager.secretAccessor"
  "roles/cloudbuild.builds.editor"
)

for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="${ROLE}"
done

# Create Workload Identity Pool if it doesn't exist
echo "Setting up Workload Identity..."
if ! gcloud iam workload-identity-pools describe github-pool --location=global --project=${PROJECT_ID} &>/dev/null; then
  gcloud iam workload-identity-pools create github-pool \
    --project=${PROJECT_ID} \
    --location=global \
    --display-name="GitHub Actions Pool"
fi

# Create Workload Identity Provider if it doesn't exist
if ! gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-pool \
  --location=global \
  --project=${PROJECT_ID} &>/dev/null; then
  
  gcloud iam workload-identity-pools providers create-oidc github-provider \
    --project=${PROJECT_ID} \
    --location=global \
    --workload-identity-pool=github-pool \
    --display-name="GitHub Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --issuer-uri="https://token.actions.githubusercontent.com"
fi

# Add IAM binding for GitHub repository
GITHUB_ORG="giortech1"  # Replace with your GitHub org name
GITHUB_REPO="org-infrastructure"  # Replace with your repo name

gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"

# Create a storage bucket for artifacts if it doesn't exist
echo "Setting up storage bucket..."
BUCKET_NAME="${PROJECT_ID}-artifacts"
if ! gcloud storage buckets describe gs://${BUCKET_NAME} --project=${PROJECT_ID} &>/dev/null; then
  gcloud storage buckets create gs://${BUCKET_NAME} \
    --project=${PROJECT_ID} \
    --location=${REGION} \
    --uniform-bucket-level-access
fi

# Print project information
echo "===== Project Setup Complete ====="
echo "Project ID: ${PROJECT_ID}"
echo "Environment: ${ENVIRONMENT}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo "Workload Identity Provider: projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
echo "Artifact Bucket: gs://${BUCKET_NAME}"
echo ""
echo "Use these values in your GitHub workflow files"