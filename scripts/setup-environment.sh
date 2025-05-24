#!/bin/bash
# Setup script to prepare GCP projects for deployment

set -e

# Configuration
BILLING_ACCOUNT_ID="0141E4-398D5E-91A063"
GITHUB_ORG="giortech1"
GITHUB_REPO="org-infrastructure"

# Project configurations
declare -A PROJECTS=(
    ["giortech-dev-project"]="653675374627"
    ["giortech-uat-project"]="28962750525"
    ["giortech-prod-project"]="371831144642"
    ["waspwallet-dev-project"]="260301647000"
    ["waspwallet-uat-project"]="875164789138"
    ["waspwallet-prod-project"]="142392555937"
    ["academyaxis-dev-project"]="1052274887859"
    ["academyaxis-uat-project"]="415071431590"
    ["academyaxis-prod-project"]="552816176477"
)

# Required APIs
REQUIRED_APIS=(
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "compute.googleapis.com"
    "storage.googleapis.com"
    "iam.googleapis.com"
    "secretmanager.googleapis.com"
    "dns.googleapis.com"
    "monitoring.googleapis.com"
    "logging.googleapis.com"
    "billingbudgets.googleapis.com"
    "certificatemanager.googleapis.com"
    "iamcredentials.googleapis.com"
)

# Function to setup a single project
setup_project() {
    local PROJECT_ID=$1
    local PROJECT_NUMBER=$2
    
    echo "Setting up project: $PROJECT_ID"
    
    # Set current project
    gcloud config set project $PROJECT_ID
    
    # Enable required APIs
    echo "Enabling APIs for $PROJECT_ID..."
    for API in "${REQUIRED_APIS[@]}"; do
        gcloud services enable $API --project=$PROJECT_ID
    done
    
    # Create service account if it doesn't exist
    if ! gcloud iam service-accounts describe github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID &>/dev/null; then
        echo "Creating service account for $PROJECT_ID..."
        gcloud iam service-accounts create github-actions-sa \
            --display-name="GitHub Actions Service Account" \
            --project=$PROJECT_ID
    fi
    
    # Grant necessary roles
    SA_EMAIL="github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
    ROLES=(
        "roles/run.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/secretmanager.secretAccessor"
        "roles/cloudbuild.builds.editor"
        "roles/compute.networkAdmin"
        "roles/dns.admin"
        "roles/certificatemanager.editor"
        "roles/monitoring.editor"
        "roles/logging.admin"
    )
    
    echo "Granting roles to service account..."
    for ROLE in "${ROLES[@]}"; do
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$ROLE" \
            --quiet
    done
    
    # Create Workload Identity Pool if it doesn't exist
    if ! gcloud iam workload-identity-pools describe github-pool --location=global --project=$PROJECT_ID &>/dev/null; then
        echo "Creating Workload Identity Pool for $PROJECT_ID..."
        gcloud iam workload-identity-pools create github-pool \
            --project=$PROJECT_ID \
            --location=global \
            --display-name="GitHub Actions Pool"
    fi
    
    # Create Workload Identity Provider if it doesn't exist  
    if ! gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --project=$PROJECT_ID &>/dev/null; then
        
        echo "Creating Workload Identity Provider for $PROJECT_ID..."
        gcloud iam workload-identity-pools providers create-oidc github-provider \
            --project=$PROJECT_ID \
            --location=global \
            --workload-identity-pool=github-pool \
            --display-name="GitHub Provider" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-condition="assertion.repository_owner == '$GITHUB_ORG'"
    fi
    
    # Add IAM binding for GitHub repository
    echo "Adding IAM binding for GitHub repository..."
    gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
        --project=$PROJECT_ID \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/$GITHUB_ORG/$GITHUB_REPO" \
        --quiet
    
    echo "✅ Project $PROJECT_ID setup complete!"
    echo
}

# Main execution
echo "Starting AcademyAxis.io GCP Environment Setup..."
echo "================================================="

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed. Please install it first."
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" >/dev/null 2>&1; then
    echo "❌ You are not authenticated with gcloud. Please run 'gcloud auth login'"
    exit 1
fi

# Setup each project
for PROJECT_ID in "${!PROJECTS[@]}"; do
    PROJECT_NUMBER=${PROJECTS[$PROJECT_ID]}
    setup_project $PROJECT_ID $PROJECT_NUMBER
done

# Create Terraform state bucket if it doesn't exist
TERRAFORM_BUCKET="academyaxis-terraform-state"
if ! gcloud storage buckets describe gs://$TERRAFORM_BUCKET &>/dev/null; then
    echo "Creating Terraform state bucket..."
    gcloud storage buckets create gs://$TERRAFORM_BUCKET \
        --location=us-central1 \
        --uniform-bucket-level-access \
        --project=giortech-dev-project
fi

echo "🎉 All projects setup complete!"
echo "You can now run your GitHub Actions workflows."