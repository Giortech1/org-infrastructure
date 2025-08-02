#!/bin/bash
# Setup script to prepare GCP projects for deployment
# Updated to include academyaxis-237 projects

set -e

# Configuration
BILLING_ACCOUNT_ID="0141E4-398D5E-91A063"
GITHUB_ORG="giortech1"
GITHUB_REPO="org-infrastructure"
ORGANIZATION_ID="126324232219"  # AcademyAxis.io organization ID

# Project configurations - EXISTING PROJECTS (already created)
declare -A EXISTING_PROJECTS=(
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

# NEW PROJECTS TO CREATE - academyaxis-237
declare -A NEW_PROJECTS=(
    ["academyaxis-237-dev-project"]=""
    ["academyaxis-237-uat-project"]=""
    ["academyaxis-237-prod-project"]=""
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
    "artifactregistry.googleapis.com"
    "serviceusage.googleapis.com"
    "firebase.googleapis.com"
    "firestore.googleapis.com"
    "firebasedatabase.googleapis.com"
    "firebasehosting.googleapis.com"
    "firebaserules.googleapis.com"
    "firebaseremoteconfig.googleapis.com"
)

# Required IAM roles
REQUIRED_ROLES=(
    "roles/serviceusage.serviceUsageAdmin"
    "roles/run.admin"
    "roles/storage.admin"
    "roles/artifactregistry.admin"
    "roles/iam.serviceAccountUser"
    "roles/iam.serviceAccountTokenCreator"
    "roles/secretmanager.secretAccessor"
    "roles/cloudbuild.builds.editor"
    "roles/compute.networkAdmin"
    "roles/dns.admin"
    "roles/monitoring.editor"
    "roles/logging.admin"
    "roles/certificatemanager.editor"
    "roles/firebase.admin"
    "roles/datastore.user"
    "roles/firebasedatabase.admin"
    "roles/firebasehosting.admin"
    "roles/firebaserules.admin"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        echo -e "${RED}❌ You are not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
        exit 1
    fi
    
    if ! gcloud billing accounts describe $BILLING_ACCOUNT_ID &>/dev/null; then
        echo -e "${RED}❌ Cannot access billing account $BILLING_ACCOUNT_ID. Please check permissions.${NC}"
        exit 1
    fi
    
    if ! gcloud organizations describe $ORGANIZATION_ID &>/dev/null; then
        echo -e "${RED}❌ Cannot access organization $ORGANIZATION_ID. Please check permissions.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed!${NC}"
}

# Function to create a new GCP project
create_new_project() {
    local PROJECT_ID=$1
    local ENVIRONMENT=""
    
    # Determine environment from project ID
    if [[ "$PROJECT_ID" == *"-dev-"* ]]; then
        ENVIRONMENT="Development"
    elif [[ "$PROJECT_ID" == *"-uat-"* ]]; then
        ENVIRONMENT="UAT"
    elif [[ "$PROJECT_ID" == *"-prod-"* ]]; then
        ENVIRONMENT="Production"
    else
        ENVIRONMENT="Unknown"
    fi
    
    echo -e "${BLUE}🏗️ Creating new project: $PROJECT_ID${NC}"
    
    # Check if project already exists
    if gcloud projects describe $PROJECT_ID &>/dev/null; then
        echo -e "${YELLOW}⚠️ Project $PROJECT_ID already exists. Getting project number...${NC}"
        local PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
        NEW_PROJECTS[$PROJECT_ID]=$PROJECT_NUMBER
        echo -e "${GREEN}✅ Found existing project: $PROJECT_ID (Number: $PROJECT_NUMBER)${NC}"
        return 0
    fi
    
    # Create the project
    echo "  Creating GCP project..."
    gcloud projects create $PROJECT_ID \
        --organization=$ORGANIZATION_ID \
        --name="AcademyAxis-237 $ENVIRONMENT Environment" \
        --labels=application=academyaxis-237,environment=${ENVIRONMENT,,},organization=academyaxis
    
    # Link billing account
    echo "  Linking billing account..."
    gcloud billing projects link $PROJECT_ID \
        --billing-account=$BILLING_ACCOUNT_ID
    
    # Get project number and store it
    local PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
    NEW_PROJECTS[$PROJECT_ID]=$PROJECT_NUMBER
    
    echo -e "${GREEN}✅ Project created: $PROJECT_ID (Number: $PROJECT_NUMBER)${NC}"
}

# Function to setup a single project (existing logic from your original script)
setup_project() {
    local PROJECT_ID=$1
    local PROJECT_NUMBER=$2
    
    echo -e "${BLUE}⚙️ Setting up project: $PROJECT_ID${NC}"
    
    # Set current project
    gcloud config set project $PROJECT_ID
    
    # Enable required APIs
    echo "  📡 Enabling APIs..."
    for API in "${REQUIRED_APIS[@]}"; do
        gcloud services enable $API --project=$PROJECT_ID --quiet
    done
    
    # Create service account if it doesn't exist
    local SA_EMAIL="github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
    if ! gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
        echo "  👤 Creating service account..."
        gcloud iam service-accounts create github-actions-sa \
            --display-name="GitHub Actions Service Account" \
            --description="Service account for GitHub Actions workflows" \
            --project=$PROJECT_ID
    fi
    
    # Grant necessary roles
    echo "  🔑 Granting IAM roles..."
    for ROLE in "${REQUIRED_ROLES[@]}"; do
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$ROLE" \
            --quiet
    done
    
    # Create Workload Identity Pool
    echo "  🔐 Setting up Workload Identity Pool..."
    if ! gcloud iam workload-identity-pools describe github-pool \
        --location=global \
        --project=$PROJECT_ID &>/dev/null; then
        
        gcloud iam workload-identity-pools create github-pool \
            --project=$PROJECT_ID \
            --location=global \
            --display-name="GitHub Actions Pool"
    fi
    
    # Create Workload Identity Provider
    echo "  🔗 Setting up Workload Identity Provider..."
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
            --attribute-condition="assertion.repository_owner=='${GITHUB_ORG}'"
    fi
    
    # Add IAM binding for GitHub repository
    echo "  🔄 Configuring Workload Identity IAM binding..."
    gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
        --project=$PROJECT_ID \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}" \
        --quiet
    
    # Create Artifact Registry repository for academyaxis-237 projects
    if [[ "$PROJECT_ID" == *"academyaxis-237"* ]]; then
        local ENV=""
        if [[ "$PROJECT_ID" == *"-dev-"* ]]; then
            ENV="dev"
        elif [[ "$PROJECT_ID" == *"-uat-"* ]]; then
            ENV="uat"
        elif [[ "$PROJECT_ID" == *"-prod-"* ]]; then
            ENV="prod"
        fi
        
        if [[ -n "$ENV" ]]; then
            echo "  📦 Creating Artifact Registry repository..."
            local REPO_NAME="academyaxis-237-$ENV"
            if ! gcloud artifacts repositories describe $REPO_NAME \
                --location=us-central1 \
                --project=$PROJECT_ID &>/dev/null; then
                
                gcloud artifacts repositories create $REPO_NAME \
                    --repository-format=docker \
                    --location=us-central1 \
                    --description="Docker repository for AcademyAxis-237 $ENV environment" \
                    --project=$PROJECT_ID
            fi
        fi
    fi
    
    # Create storage bucket for artifacts if it doesn't exist
    echo "  🪣 Setting up storage bucket..."
    local BUCKET_NAME="${PROJECT_ID}-artifacts"
    if ! gcloud storage buckets describe gs://$BUCKET_NAME --project=$PROJECT_ID &>/dev/null; then
        gcloud storage buckets create gs://$BUCKET_NAME \
            --location=us-central1 \
            --uniform-bucket-level-access \
            --project=$PROJECT_ID
        
        # Set lifecycle rules
        cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }
    ]
  }
}
EOF
        gcloud storage buckets update gs://$BUCKET_NAME --lifecycle-file=/tmp/lifecycle.json
        rm /tmp/lifecycle.json
    fi
    
    echo -e "${GREEN}✅ Project setup completed: $PROJECT_ID${NC}"
}

# Function to update configuration files
update_configuration_files() {
    echo -e "${BLUE}📝 Updating configuration files...${NC}"
    
    # Update project-config.yml if any new projects were created
    local new_projects_created=false
    for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
        if [[ -n "${NEW_PROJECTS[$PROJECT_ID]}" ]]; then
            new_projects_created=true
            break
        fi
    done
    
    if [[ "$new_projects_created" == true ]]; then
        if [ -f ".github/config/project-config.yml" ]; then
            echo "  Updating .github/config/project-config.yml..."
            
            # Check if academyaxis237 section already exists
            if ! grep -q "academyaxis237:" ".github/config/project-config.yml"; then
                # Add academyaxis237 configuration
                cat >> ".github/config/project-config.yml" << EOF

# AcademyAxis-237 Application Configuration
academyaxis237:
  dev:
    project_id: "academyaxis-237-dev-project"
    project_number: "${NEW_PROJECTS["academyaxis-237-dev-project"]}"
    region: "us-central1"
    service_name: "academyaxis237-dev"
    min_instances: 0
    max_instances: 5
    memory: "512Mi"
    cpu: 1
  uat:
    project_id: "academyaxis-237-uat-project"
    project_number: "${NEW_PROJECTS["academyaxis-237-uat-project"]}"
    region: "us-central1"
    service_name: "academyaxis237-uat"
    min_instances: 0
    max_instances: 10
    memory: "512Mi"
    cpu: 1
  prod:
    project_id: "academyaxis-237-prod-project"
    project_number: "${NEW_PROJECTS["academyaxis-237-prod-project"]}"
    region: "us-central1"
    service_name: "academyaxis237-prod"
    min_instances: 1
    max_instances: 5
    memory: "1Gi"
    cpu: 2
EOF
                echo "  ✅ Added academyaxis237 configuration to project-config.yml"
            else
                echo "  ⚠️ academyaxis237 configuration already exists in project-config.yml"
            fi
        else
            echo "  ⚠️ .github/config/project-config.yml not found"
        fi
    fi
    
    echo -e "${GREEN}✅ Configuration files updated${NC}"
}

# Function to create Terraform configurations
create_terraform_configs() {
    echo -e "${BLUE}📝 Creating Terraform configurations for new projects...${NC}"
    
    for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
        local PROJECT_NUMBER="${NEW_PROJECTS[$PROJECT_ID]}"
        if [[ -z "$PROJECT_NUMBER" ]]; then
            continue
        fi
        
        local ENVIRONMENT=""
        local BUDGET=50
        
        if [[ "$PROJECT_ID" == *"-dev-"* ]]; then
            ENVIRONMENT="dev"
            BUDGET=50
        elif [[ "$PROJECT_ID" == *"-uat-"* ]]; then
            ENVIRONMENT="uat"
            BUDGET=50
        elif [[ "$PROJECT_ID" == *"-prod-"* ]]; then
            ENVIRONMENT="prod"
            BUDGET=100
        fi
        
        if [[ -n "$ENVIRONMENT" ]]; then
            echo "  Creating Terraform config for $PROJECT_ID ($ENVIRONMENT)..."
            
            # Create directory structure
            local TF_DIR="terraform/organization/academyaxis237/$ENVIRONMENT"
            mkdir -p "$TF_DIR"
            
            # Create main.tf
            cat > "$TF_DIR/main.tf" << 'EOF'
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "academyaxis-terraform-state"
    prefix = "academyaxis237/ENV_PLACEHOLDER"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Workload Identity for GitHub Actions
module "workload_identity" {
  source = "../../../modules/workload_identity"
  
  project_id             = var.project_id
  github_org             = "giortech1"
  github_repo            = "org-infrastructure"
  create_identity_pool   = var.create_identity_pool
  create_service_account = var.create_service_account
}

# Cost controls and monitoring
module "cost_controls" {
  source = "../../../modules/cost_controls"
  
  project_id          = var.project_id
  application         = "academyaxis237"
  environment         = var.environment
  region              = var.region
  billing_account_id  = var.billing_account_id
  budget_amount       = var.budget_amount
  alert_email_address = var.alert_email_address
  create_budget       = var.create_budget
}

# Basic storage bucket for testing
resource "google_storage_bucket" "storage" {
  name          = "${var.project_id}-bucket"
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}
EOF
            
            # Replace placeholder with actual environment
            sed -i "s/ENV_PLACEHOLDER/$ENVIRONMENT/g" "$TF_DIR/main.tf"
            
            # Create variables.tf
            cat > "$TF_DIR/variables.tf" << EOF
variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "$PROJECT_ID"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, uat, prod)"
  type        = string
  default     = "$ENVIRONMENT"
}

variable "billing_account_id" {
  description = "Billing account ID"
  type        = string
  default     = "0141E4-398D5E-91A063"
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = $BUDGET
}

variable "alert_email_address" {
  description = "Email address for alerts"
  type        = string
  default     = "admin@giortech.com"
}

variable "create_identity_pool" {
  description = "Whether to create the workload identity pool"
  type        = bool
  default     = false
}

variable "create_service_account" {
  description = "Whether to create the service account"
  type        = bool
  default     = false
}

variable "create_budget" {
  description = "Whether to create budget"
  type        = bool
  default     = true
}
EOF
            
            # Create outputs.tf
            cat > "$TF_DIR/outputs.tf" << EOF
output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = "$PROJECT_NUMBER"
}

output "workload_identity_provider" {
  description = "Workload Identity Provider"
  value       = module.workload_identity.workload_identity_provider
}

output "service_account_email" {
  description = "Service Account email"
  value       = module.workload_identity.service_account_email
}

output "budget_id" {
  description = "Budget ID"
  value       = module.cost_controls.budget_id
}

output "cost_dashboards" {
  description = "Cost monitoring dashboards"
  value       = module.cost_controls.dashboards
}

output "bucket_name" {
  description = "Storage bucket name"
  value       = google_storage_bucket.storage.name
}
EOF
            
            # Create terraform.tfvars
            cat > "$TF_DIR/terraform.tfvars" << EOF
project_id         = "$PROJECT_ID"
region             = "us-central1"
environment        = "$ENVIRONMENT"
billing_account_id = "0141E4-398D5E-91A063"
budget_amount      = $BUDGET
alert_email_address = "admin@giortech.com"
create_identity_pool   = false
create_service_account = false
create_budget          = true
EOF
        fi
    done
    
    echo -e "${GREEN}✅ Terraform configurations created${NC}"
}

# Function to display summary
display_summary() {
    echo -e "\n${GREEN}🎉 Setup Complete!${NC}"
    echo -e "${BLUE}==================${NC}"
    
    # Show existing projects
    echo -e "\n${YELLOW}📋 Existing Projects (already set up):${NC}"
    for PROJECT_ID in "${!EXISTING_PROJECTS[@]}"; do
        PROJECT_NUMBER=${EXISTING_PROJECTS[$PROJECT_ID]}
        echo "  ✅ $PROJECT_ID (Number: $PROJECT_NUMBER)"
    done
    
    # Show new projects created
    local new_projects_created=false
    echo -e "\n${YELLOW}🆕 New Projects Created:${NC}"
    for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
        PROJECT_NUMBER=${NEW_PROJECTS[$PROJECT_ID]}
        if [[ -n "$PROJECT_NUMBER" ]]; then
            echo "  ✅ $PROJECT_ID (Number: $PROJECT_NUMBER)"
            new_projects_created=true
        fi
    done
    
    if [[ "$new_projects_created" == false ]]; then
        echo "  ⚠️ No new projects were created (they may already exist)"
    fi
    
    # Show next steps
    echo -e "\n${YELLOW}🚀 Next Steps:${NC}"
    echo "1. Update your GitHub workflow files to include academyaxis237 in choices"
    echo "2. Create the academyaxis-237 application repository"
    echo "3. Test deployment using the GitHub Actions workflows"
    echo "4. Configure DNS and load balancer using network-deploy.yml"
    
    # Show Workload Identity information for new projects
    if [[ "$new_projects_created" == true ]]; then
        echo -e "\n${YELLOW}🔗 Workload Identity Providers (New Projects):${NC}"
        for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
            PROJECT_NUMBER=${NEW_PROJECTS[$PROJECT_ID]}
            if [[ -n "$PROJECT_NUMBER" ]]; then
                echo "  $PROJECT_ID:"
                echo "    Provider: projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
                echo "    SA Email: github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
            fi
        done
    fi
}

# Main execution function
main() {
    local MODE=${1:-"all"}
    
    echo -e "${BLUE}🚀 AcademyAxis.io GCP Environment Setup${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    case "$MODE" in
        "new"|"academyaxis237")
            echo -e "${YELLOW}Mode: Setting up NEW academyaxis-237 projects only${NC}"
            check_prerequisites
            
            # Create new projects
            for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
                create_new_project "$PROJECT_ID"
            done
            
            # Setup new projects
            for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
                PROJECT_NUMBER=${NEW_PROJECTS[$PROJECT_ID]}
                if [[ -n "$PROJECT_NUMBER" ]]; then
                    setup_project "$PROJECT_ID" "$PROJECT_NUMBER"
                fi
            done
            
            create_terraform_configs
            update_configuration_files
            display_summary
            ;;
        
        "existing")
            echo -e "${YELLOW}Mode: Setting up EXISTING projects only${NC}"
            check_prerequisites
            
            # Setup existing projects
            for PROJECT_ID in "${!EXISTING_PROJECTS[@]}"; do
                PROJECT_NUMBER=${EXISTING_PROJECTS[$PROJECT_ID]}
                setup_project "$PROJECT_ID" "$PROJECT_NUMBER"
            done
            
            display_summary
            ;;
        
        "all"|*)
            echo -e "${YELLOW}Mode: Setting up ALL projects (existing + new)${NC}"
            check_prerequisites
            
            # Setup existing projects first
            echo -e "\n${BLUE}Setting up existing projects...${NC}"
            for PROJECT_ID in "${!EXISTING_PROJECTS[@]}"; do
                PROJECT_NUMBER=${EXISTING_PROJECTS[$PROJECT_ID]}
                setup_project "$PROJECT_ID" "$PROJECT_NUMBER"
            done
            
            # Create and setup new projects
            echo -e "\n${BLUE}Creating and setting up new projects...${NC}"
            for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
                create_new_project "$PROJECT_ID"
            done
            
            for PROJECT_ID in "${!NEW_PROJECTS[@]}"; do
                PROJECT_NUMBER=${NEW_PROJECTS[$PROJECT_ID]}
                if [[ -n "$PROJECT_NUMBER" ]]; then
                    setup_project "$PROJECT_ID" "$PROJECT_NUMBER"
                fi
            done
            
            create_terraform_configs
            update_configuration_files
            display_summary
            ;;
    esac
}

# Create Terraform state bucket if it doesn't exist
ensure_terraform_bucket() {
    local TERRAFORM_BUCKET="academyaxis-terraform-state"
    if ! gcloud storage buckets describe gs://$TERRAFORM_BUCKET &>/dev/null; then
        echo -e "${BLUE}Creating Terraform state bucket...${NC}"
        gcloud storage buckets create gs://$TERRAFORM_BUCKET \
            --location=us-central1 \
            --uniform-bucket-level-access \
            --project=giortech-dev-project
    fi
}

# Show usage information
show_usage() {
    echo "Usage: $0 [MODE]"
    echo ""
    echo "Modes:"
    echo "  all (default)    - Setup all projects (existing + new academyaxis-237)"
    echo "  new|academyaxis237 - Setup only NEW academyaxis-237 projects"
    echo "  existing         - Setup only existing projects"
    echo ""
    echo "Examples:"
    echo "  $0                    # Setup all projects"
    echo "  $0 new                # Setup only new academyaxis-237 projects"
    echo "  $0 existing           # Setup only existing projects"
}

# Handle help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Ensure Terraform bucket exists
ensure_terraform_bucket

# Run main function with provided arguments
main "$@"