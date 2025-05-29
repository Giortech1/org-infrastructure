#!/bin/bash
# Setup script for consistent project configuration
# Usage: ./setup-project.sh <project-id> <environment>

# First, check if we're in a directory with Terraform files
if [ -f "main.tf" ] || [ -f "outputs.tf" ]; then
  echo "Attempting to get Workload Identity from Terraform outputs..."
  
  # Try to get outputs but with better error handling
  set +e  # Don't exit on error for these commands
  PROVIDER=$(terraform output -raw workload_identity_provider 2>/dev/null)
  PROVIDER_EXIT=$?
  SA_EMAIL=$(terraform output -raw service_account_email 2>/dev/null)
  SA_EXIT=$?
  set -e  # Re-enable exit on error
  
  # Check if commands succeeded
  if [ $PROVIDER_EXIT -ne 0 ] || [ $SA_EXIT -ne 0 ] || [ -z "$PROVIDER" ] || [ -z "$SA_EMAIL" ]; then
    echo "Warning: Could not get Workload Identity Provider or Service Account from Terraform outputs"
    echo "Using direct lookup method instead"
    
    # Get project number directly
    PROJECT_NUMBER=$(gcloud projects describe ${{ needs.determine-context.outputs.project_id }} --format='value(projectNumber)')
    PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
    SA_EMAIL="github-actions-sa@${{ needs.determine-context.outputs.project_id }}.iam.gserviceaccount.com"
  fi
else
  echo "Not in a Terraform directory, using direct lookup method"
  
  # Get project number directly
  PROJECT_NUMBER=$(gcloud projects describe ${{ needs.determine-context.outputs.project_id }} --format='value(projectNumber)')
  PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
  SA_EMAIL="github-actions-sa@${{ needs.determine-context.outputs.project_id }}.iam.gserviceaccount.com"
fi

echo "wi_provider=$PROVIDER" >> $GITHUB_OUTPUT
echo "sa_email=$SA_EMAIL" >> $GITHUB_OUTPUT

echo "Using Workload Identity Provider: $PROVIDER"
echo "Using Service Account: $SA_EMAIL"
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

# Check if main.tf exists, create if needed
if [ ! -f "main.tf" ]; then
  echo "Creating main.tf as it doesn't exist..."
  cat > main.tf << 'EOFMAIN'
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = var.bucket_name
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Basic resources for testing
resource "google_storage_bucket" "storage" {
  name          = "${var.project_id}-bucket"
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}

# Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "environment" {
  description = "Environment (dev, uat, prod)"
  type        = string
}

# Outputs
output "project_id" {
  value       = var.project_id
  description = "The GCP project ID"
}

output "bucket_name" {
  value       = google_storage_bucket.storage.name
  description = "Storage bucket name"
}
EOFMAIN
else
  echo "main.tf already exists, using existing file"
fi
if [ -f "terraform.tfvars" ]; then
  echo "terraform.tfvars already exists. Do you want to overwrite it? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    echo "Skipping creation of terraform.tfvars."
    exit 0
  fi
fi

cat > terraform.tfvars << EOF
project_id  = "giortech-dev-project"
region      = "us-central1"
environment = "dev"
EOF

echo "Created terraform.tfvars:"
cat terraform.tfvars
echo "Created terraform.tfvars:"
cat terraform.tfvars
