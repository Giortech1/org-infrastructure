#!/bin/bash
# simple-deploy.sh - Simplified deployment script for WaspWallet and AcademyAxis

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}íº€ Setting up WaspWallet and AcademyAxis Infrastructure${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}âŒ gcloud CLI not found. Please install Google Cloud SDK first.${NC}"
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${RED}âŒ Not authenticated with gcloud. Run: gcloud auth login${NC}"
    exit 1
fi

echo -e "${GREEN}âœ… Prerequisites check passed${NC}"

# Project configurations
declare -A PROJECTS=(
    ["waspwallet-dev-project"]="260301647000"
    ["waspwallet-uat-project"]="875164789138"
    ["waspwallet-prod-project"]="142392555937"
    ["academyaxis-dev-project"]="1052274887859"
    ["academyaxis-uat-project"]="415071431590"
    ["academyaxis-prod-project"]="552816176477"
)

# Step 1: Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p terraform/organization/waspwallet/{dev,uat,prod}
mkdir -p terraform/organization/academyaxis/{dev,uat,prod}
echo -e "${GREEN}âœ… Directory structure created${NC}"

# Step 2: Setup workload identity for each project
setup_project() {
    local PROJECT_ID=$1
    local PROJECT_NUMBER=$2
    
    echo -e "${YELLOW}Setting up $PROJECT_ID...${NC}"
    
    # Enable required APIs
    echo "  Enabling APIs..."
    gcloud services enable \
        iam.googleapis.com \
        iamcredentials.googleapis.com \
        cloudresourcemanager.googleapis.com \
        run.googleapis.com \
        cloudbuild.googleapis.com \
        storage.googleapis.com \
        secretmanager.googleapis.com \
        dns.googleapis.com \
        monitoring.googleapis.com \
        logging.googleapis.com \
        --project=$PROJECT_ID --quiet || echo "  Warning: Some APIs may already be enabled"
    
    # Create service account
    echo "  Creating service account..."
    if ! gcloud iam service-accounts describe github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com --project=$PROJECT_ID &>/dev/null; then
        gcloud iam service-accounts create github-actions-sa \
            --display-name="GitHub Actions Service Account" \
            --project=$PROJECT_ID
    else
        echo "  Service account already exists"
    fi
    
    # Grant roles
    echo "  Granting IAM roles..."
    SA_EMAIL="github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
    ROLES=(
        "roles/run.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/secretmanager.secretAccessor"
        "roles/cloudbuild.builds.editor"
        "roles/compute.networkAdmin"
        "roles/dns.admin"
        "roles/monitoring.editor"
        "roles/logging.admin"
    )
    
    for ROLE in "${ROLES[@]}"; do
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$ROLE" \
            --quiet || echo "  Warning: Role $ROLE may already be assigned"
    done
    
    # Create Workload Identity Pool
    echo "  Setting up Workload Identity..."
    if ! gcloud iam workload-identity-pools describe github-pool --location=global --project=$PROJECT_ID &>/dev/null; then
        gcloud iam workload-identity-pools create github-pool \
            --project=$PROJECT_ID \
            --location=global \
            --display-name="GitHub Actions Pool"
    else
        echo "  Workload Identity Pool already exists"
    fi
    
    # Create Workload Identity Provider
    if ! gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --project=$PROJECT_ID &>/dev/null; then
        
        gcloud iam workload-identity-pools providers create-oidc github-provider \
            --project=$PROJECT_ID \
            --location=global \
            --workload-identity-pool=github-pool \
            --display-name="GitHub Provider" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-condition="assertion.repository_owner == 'giortech1'"
    else
        echo "  Workload Identity Provider already exists"
    fi
    
    # Add IAM binding for GitHub repository
    echo "  Configuring repository access..."
    gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
        --project=$PROJECT_ID \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/giortech1/org-infrastructure" \
        --quiet || echo "  Warning: IAM binding may already exist"
    
    echo -e "${GREEN}âœ… $PROJECT_ID setup complete${NC}"
}

# Setup all projects
for PROJECT_ID in "${!PROJECTS[@]}"; do
    PROJECT_NUMBER=${PROJECTS[$PROJECT_ID]}
    setup_project $PROJECT_ID $PROJECT_NUMBER
done

echo -e "${GREEN}í¾‰ Infrastructure setup completed!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Copy Terraform files to the created directories"
echo -e "2. Navigate to terraform/organization/waspwallet/dev and run 'terraform init'"
echo -e "3. Test with 'terraform plan'"
echo -e "4. Deploy with 'terraform apply'"
