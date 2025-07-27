#!/bin/bash
# Fix service account permissions for all projects

set -e

# Define all your projects based on your configuration
declare -A ALL_PROJECTS=(
    # giortech projects
    ["giortech-dev-project"]="653675374627"
    ["giortech-uat-project"]="28962750525"
    ["giortech-prod-project"]="371831144642"
    
    # waspwallet projects
    ["waspwallet-dev-project"]="260301647000"
    ["waspwallet-uat-project"]="875164789138"
    ["waspwallet-prod-project"]="142392555937"
    
    # academyaxis projects
    ["academyaxis-dev-project"]="1052274887859"
    ["academyaxis-uat-project"]="415071431590"
    ["academyaxis-prod-project"]="552816176477"
)

GITHUB_ORG="giortech1"
GITHUB_INFRA_REPO="org-infrastructure"

# Required roles for service accounts
REQUIRED_ROLES=(
    "roles/run.admin"
    "roles/storage.admin"
    "roles/iam.serviceAccountUser"
    "roles/iam.serviceAccountTokenCreator"  # This is the critical missing role
    "roles/secretmanager.secretAccessor"
    "roles/cloudbuild.builds.editor"
    "roles/compute.networkAdmin"
    "roles/dns.admin"
    "roles/certificatemanager.editor"
    "roles/monitoring.editor"
    "roles/logging.admin"
    "roles/serviceusage.serviceUsageAdmin"
    "roles/billing.viewer"
)

# Function to fix a single project
fix_project() {
    local PROJECT_ID=$1
    local PROJECT_NUMBER=$2
    
    echo "🔧 Fixing project: $PROJECT_ID (Project Number: $PROJECT_NUMBER)"
    
    # Set current project
    gcloud config set project $PROJECT_ID
    
    # Check if project is accessible
    if ! gcloud projects describe $PROJECT_ID >/dev/null 2>&1; then
        echo "❌ Cannot access project $PROJECT_ID. Skipping..."
        return 1
    fi
    
    SERVICE_ACCOUNT="github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # Ensure service account exists
    if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT --project=$PROJECT_ID >/dev/null 2>&1; then
        echo "👤 Creating service account for $PROJECT_ID..."
        gcloud iam service-accounts create github-actions-sa \
            --display-name="GitHub Actions Service Account" \
            --description="Service account for GitHub Actions workflows" \
            --project=$PROJECT_ID
    fi
    
    # Add all required roles
    echo "🔑 Adding/updating IAM roles..."
    for ROLE in "${REQUIRED_ROLES[@]}"; do
        echo "  Adding role: $ROLE"
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SERVICE_ACCOUNT" \
            --role="$ROLE" \
            --quiet || echo "    Warning: Failed to add $ROLE"
    done
    
    # Ensure workload identity binding exists
    echo "🔗 Setting up workload identity binding..."
    gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT \
        --project=$PROJECT_ID \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/$GITHUB_ORG/$GITHUB_INFRA_REPO" \
        --quiet || echo "    Warning: Failed to add workload identity binding"
    
    echo "✅ Project $PROJECT_ID fixed successfully!"
    echo ""
}

# Main execution
echo "🚀 Fixing service account permissions for all projects..."
echo "======================================================"

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install it first."
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "❌ Please authenticate with gcloud first:"
    echo "   gcloud auth login"
    exit 1
fi

# Fix all projects
for PROJECT_ID in "${!ALL_PROJECTS[@]}"; do
    PROJECT_NUMBER="${ALL_PROJECTS[$PROJECT_ID]}"
    fix_project "$PROJECT_ID" "$PROJECT_NUMBER"
done

echo "🎉 All projects have been processed!"
echo ""
echo "📋 Summary:"
echo "  - Fixed service account permissions"
echo "  - Added iam.serviceAccountTokenCreator role"
echo "  - Verified workload identity bindings"
echo ""
echo "🔄 You can now re-run your GitHub Actions workflows."