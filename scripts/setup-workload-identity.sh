#!/bin/bash

# Variables
ORG_ID="126324232219"
GITHUB_ORG="giortech1"
PROJECTS=("giortech-dev-project" "giortech-uat-project" "giortech-prod-project")

# Create workload identity pools for each project
for PROJECT in "${PROJECTS[@]}"; do
    # Enable necessary APIs
    gcloud services enable iamcredentials.googleapis.com --project=$PROJECT
    gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT
    gcloud services enable iam.googleapis.com --project=$PROJECT
    gcloud services enable run.googleapis.com --project=$PROJECT
    gcloud services enable cloudbuild.googleapis.com --project=$PROJECT
    gcloud services enable secretmanager.googleapis.com --project=$PROJECT

    # Create workload identity pool
    gcloud iam workload-identity-pools create "github-pool" \
        --project="$PROJECT" \
        --location="global" \
        --display-name="GitHub Actions Pool"

    # Create provider
    gcloud iam workload-identity-pools providers create-oidc "github-provider" \
        --project="$PROJECT" \
        --location="global" \
        --workload-identity-pool="github-pool" \
        --display-name="GitHub Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-condition="assertion.repository_owner=='${GITHUB_ORG}'"

    # Create service account
    SA_NAME="github-actions-sa"
    gcloud iam service-accounts create $SA_NAME \
        --project=$PROJECT \
        --display-name="GitHub Actions Service Account"

    # Grant necessary roles
    SA_EMAIL="$SA_NAME@$PROJECT.iam.gserviceaccount.com"
    gcloud projects add-iam-policy-binding $PROJECT \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/run.admin"
    gcloud projects add-iam-policy-binding $PROJECT \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/storage.admin"
    gcloud projects add-iam-policy-binding $PROJECT \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/iam.serviceAccountUser"
    gcloud projects add-iam-policy-binding $PROJECT \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/secretmanager.secretAccessor"

    # Grant repository access to the pool
    REPO_NAME="giortech-app"
    gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
        --project=$PROJECT \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe $PROJECT --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_ORG}/${REPO_NAME}"

    # Output workload identity provider resource name
    echo "Workload identity provider for $PROJECT:"
    echo "projects/$(gcloud projects describe $PROJECT --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
    echo "Service account email: $SA_EMAIL"
    echo ""
done