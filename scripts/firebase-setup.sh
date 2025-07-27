#!/bin/bash
# Complete Firebase + GCP Setup Script
# Combines existing infrastructure with Firebase-specific configuration

set -e

# Configuration
GITHUB_ORG="Giortech1"  # Update with your GitHub org
GITHUB_REPO="giortech-app"  # Update with your repo name

# Project configurations (update these with your actual project IDs and numbers)
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

# Base required APIs
BASE_APIS=(
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
    "artifactregistry.googleapis.com"
    "serviceusage.googleapis.com"
)

# Firebase-specific APIs
FIREBASE_APIS=(
    "firebase.googleapis.com"
    "firestore.googleapis.com" 
    "firebasedatabase.googleapis.com"
    "firebasehosting.googleapis.com"
    "firebaserules.googleapis.com"
    "firebaseremoteconfig.googleapis.com"
)

# Base IAM roles
BASE_ROLES=(
    "roles/serviceusage.serviceUsageAdmin"
    "roles/run.admin"
    "roles/storage.admin"
    "roles/artifactregistry.admin"
    "roles/iam.serviceAccountUser"
    "roles/secretmanager.secretAccessor"
    "roles/cloudbuild.builds.editor"
    "roles/compute.networkAdmin"
    "roles/dns.admin"
    "roles/monitoring.editor"
    "roles/logging.admin"
    "roles/certificatemanager.editor"
)

# Firebase-specific roles
FIREBASE_ROLES=(
    "roles/firebase.admin"
    "roles/datastore.user"
    "roles/firebasedatabase.admin"
    "roles/firebasehosting.admin"
    "roles/firebaserules.admin"
    "roles/firebase.admin"
)

# Function to setup a single project with Firebase support
setup_project_with_firebase() {
    local PROJECT_ID=$1
    local PROJECT_NUMBER=$2
    
    echo "🚀 Setting up project with Firebase: $PROJECT_ID"
    
    # Set current project
    gcloud config set project $PROJECT_ID
    
    # Check if project exists and is accessible
    if ! gcloud projects describe $PROJECT_ID >/dev/null 2>&1; then
        echo "❌ Cannot access project $PROJECT_ID. Please check permissions."
        return 1
    fi
    
    # Enable base APIs
    echo "📡 Enabling base APIs for $PROJECT_ID..."
    for API in "${BASE_APIS[@]}"; do
        echo "  Enabling $API..."
        gcloud services enable $API --project=$PROJECT_ID --quiet
    done
    
    # Enable Firebase APIs
    echo "📱 Enabling Firebase APIs for $PROJECT_ID..."
    for API in "${FIREBASE_APIS[@]}"; do
        echo "  Enabling $API..."
        gcloud services enable $API --project=$PROJECT_ID --quiet
    done
    
    # Create service account if it doesn't exist
    SA_EMAIL="github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
    if ! gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID >/dev/null 2>&1; then
        echo "👤 Creating service account for $PROJECT_ID..."
        gcloud iam service-accounts create github-actions-sa \
            --display-name="GitHub Actions Service Account" \
            --description="Service account for GitHub Actions workflows with Firebase access" \
            --project=$PROJECT_ID
    else
        echo "✅ Service account already exists: $SA_EMAIL"
    fi
    
    # Grant base IAM roles
    echo "🔑 Granting base IAM roles to service account..."
    for ROLE in "${BASE_ROLES[@]}"; do
        echo "  Granting $ROLE..."
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$ROLE" \
            --quiet
    done
    
    # Grant Firebase-specific roles
    echo "🔥 Granting Firebase roles to service account..."
    for ROLE in "${FIREBASE_ROLES[@]}"; do
        echo "  Granting $ROLE..."
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$ROLE" \
            --quiet
    done
    
    # Create Workload Identity Pool if it doesn't exist
    echo "🔐 Setting up Workload Identity Pool..."
    if ! gcloud iam workload-identity-pools describe github-pool \
        --location=global \
        --project=$PROJECT_ID >/dev/null 2>&1; then
        
        echo "  Creating Workload Identity Pool..."
        gcloud iam workload-identity-pools create github-pool \
            --project=$PROJECT_ID \
            --location=global \
            --display-name="GitHub Actions Pool" \
            --description="Workload Identity Pool for GitHub Actions"
    else
        echo "  ✅ Workload Identity Pool already exists"
    fi
    
    # Create Workload Identity Provider if it doesn't exist
    echo "🔗 Setting up Workload Identity Provider..."
    if ! gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --project=$PROJECT_ID >/dev/null 2>&1; then
        
        echo "  Creating Workload Identity Provider..."
        gcloud iam workload-identity-pools providers create-oidc github-provider \
            --project=$PROJECT_ID \
            --location=global \
            --workload-identity-pool=github-pool \
            --display-name="GitHub Provider" \
            --description="OIDC provider for GitHub Actions" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-condition="assertion.repository_owner=='${GITHUB_ORG}'"
    else
        echo "  ✅ Workload Identity Provider already exists"
    fi
    
    # Add IAM binding for Workload Identity
    echo "🔄 Configuring Workload Identity IAM binding..."
    gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
        --project=$PROJECT_ID \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}" \
        --quiet
    
    # Create storage bucket for artifacts if it doesn't exist
    echo "🪣 Setting up storage bucket..."
    BUCKET_NAME="${PROJECT_ID}-artifacts"
    if ! gsutil ls -b gs://$BUCKET_NAME >/dev/null 2>&1; then
        echo "  Creating storage bucket: $BUCKET_NAME"
        gsutil mb gs://$BUCKET_NAME
        gsutil lifecycle set - gs://$BUCKET_NAME <<EOF
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 30}
    }
  ]
}
EOF
    else
        echo "  ✅ Storage bucket already exists: $BUCKET_NAME"
    fi
    
    # Initialize Firebase project (if not already initialized)
    echo "🔥 Checking Firebase initialization..."
    if ! gcloud firebase projects describe $PROJECT_ID >/dev/null 2>&1; then
        echo "  Firebase project not found. You may need to initialize Firebase manually:"
        echo "  1. Go to https://console.firebase.google.com"
        echo "  2. Add Firebase to your existing GCP project: $PROJECT_ID"
        echo "  3. Enable the services you need (Firestore, Auth, etc.)"
    else
        echo "  ✅ Firebase project already initialized"
    fi
    
    echo "✅ Project setup completed: $PROJECT_ID"
    echo ""
}

# Function to display usage information
show_usage() {
    echo "Usage: $0 [PROJECT_ID] [all]"
    echo ""
    echo "Options:"
    echo "  PROJECT_ID    Setup specific project (e.g., giortech-dev-project)"
    echo "  all          Setup all configured projects"
    echo ""
    echo "Examples:"
    echo "  $0 giortech-dev-project     # Setup single project"
    echo "  $0 all                      # Setup all projects"
    echo ""
    echo "Available projects:"
    for project in "${!PROJECTS[@]}"; do
        echo "  - $project"
    done
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    if [ "$1" = "all" ]; then
        echo "🚀 Setting up all projects with Firebase support..."
        echo ""
        
        for PROJECT_ID in "${!PROJECTS[@]}"; do
            PROJECT_NUMBER=${PROJECTS[$PROJECT_ID]}
            setup_project_with_firebase "$PROJECT_ID" "$PROJECT_NUMBER"
        done
        
        echo "🎉 All projects setup completed!"
        
    elif [[ -n "${PROJECTS[$1]}" ]]; then
        PROJECT_ID=$1
        PROJECT_NUMBER=${PROJECTS[$PROJECT_ID]}
        
        echo "🚀 Setting up single project with Firebase support..."
        echo ""
        
        setup_project_with_firebase "$PROJECT_ID" "$PROJECT_NUMBER"
        
        echo "🎉 Project setup completed: $PROJECT_ID"
        
    else
        echo "❌ Unknown project: $1"
        echo ""
        show_usage
        exit 1
    fi
    
    # Display next steps
    echo ""
    echo "📋 Next Steps:"
    echo "1. Update your GitHub repository secrets with:"
    echo "   - WI_PROVIDER: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
    echo "   - WI_SERVICE_ACCOUNT: github-actions-sa@PROJECT_ID.iam.gserviceaccount.com"
    echo ""
    echo "2. Use this authentication in your GitHub Actions:"
    echo "   - uses: google-github-actions/auth@v2"
    echo "     with:"
    echo "       workload_identity_provider: \${{ secrets.WI_PROVIDER }}"
    echo "       service_account: \${{ secrets.WI_SERVICE_ACCOUNT }}"
    echo ""
    echo "3. Your Firebase Admin SDK will automatically use these credentials"
    echo "4. No service account keys needed! 🎉"
}

# Run main function with all arguments
main "$@"