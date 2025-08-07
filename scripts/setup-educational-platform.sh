#!/bin/bash
# scripts/setup-educational-platform.sh
# Setup script for AcademyAxis Educational Platform (Bitrix24-inspired)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_EDUCATIONAL_REGION="global"
DEFAULT_GRADING_SYSTEM="flexible"
DEFAULT_INFRASTRUCTURE="existing"

# Project configurations for educational platform
declare -A EDUCATIONAL_PROJECTS=(
    ["academyaxis-dev-project"]="1052274887859"
    ["academyaxis-uat-project"]="415071431590"  
    ["academyaxis-prod-project"]="552816176477"
    ["academyaxis-237-dev-project"]="425169602074"
    ["academyaxis-237-uat-project"]="523018028271"
    ["academyaxis-237-prod-project"]="684266177356"
)

# Educational platform APIs
EDUCATIONAL_APIS=(
    "run.googleapis.com"
    "firestore.googleapis.com"
    "storage.googleapis.com"
    "secretmanager.googleapis.com"
    "scheduler.googleapis.com"
    "monitoring.googleapis.com"
    "logging.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
)

show_usage() {
    echo -e "${BLUE}AcademyAxis Educational Platform Setup${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --region REGION              Educational region (global, africa, cameroon, usa, europe)"
    echo "  --infrastructure TYPE        Infrastructure type (existing, cameroon237)"
    echo "  --grading-system SYSTEM      Grading system (flexible, 4_point, 100_point, 20_point)"
    echo "  --environment ENV            Environment (dev, uat, prod, all)"
    echo "  --features LEVEL             Feature level (standard, advanced, compliance, pilot)"
    echo "  --dry-run                    Show what would be done without making changes"
    echo "  --help                       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --region global --environment dev"
    echo "  $0 --region cameroon --infrastructure cameroon237 --grading-system 20_point"
    echo "  $0 --environment all --features advanced"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites for educational platform setup..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log_error "You are not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_warning "Terraform is not installed. Educational infrastructure deployment will be skipped."
    fi
    
    log_success "All prerequisites satisfied"
}

setup_educational_project() {
    local PROJECT_ID=$1
    local PROJECT_NUMBER=$2
    local EDUCATIONAL_REGION=$3
    local GRADING_SYSTEM=$4
    
    log_info "Setting up educational platform for project: $PROJECT_ID"
    log_info "Educational region: $EDUCATIONAL_REGION"
    log_info "Grading system: $GRADING_SYSTEM"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would set up educational platform for $PROJECT_ID"
        log_info "DRY RUN: Would enable APIs: ${EDUCATIONAL_APIS[*]}"
        log_info "DRY RUN: Would create educational resources"
        return 0
    fi
    
    # Set current project
    gcloud config set project $PROJECT_ID
    
    # Check if project exists and is accessible
    if ! gcloud projects describe $PROJECT_ID >/dev/null 2>&1; then
        log_error "Cannot access project $PROJECT_ID. Please check permissions."
        return 1
    fi
    
    # Enable educational platform APIs
    log_info "Enabling educational platform APIs..."
    for API in "${EDUCATIONAL_APIS[@]}"; do
        log_info "Enabling $API..."
        gcloud services enable $API --project=$PROJECT_ID --quiet || log_warning "Failed to enable $API"
    done
    
    log_success "Educational platform setup completed for project: $PROJECT_ID"
}

main() {
    local EDUCATIONAL_REGION="$DEFAULT_EDUCATIONAL_REGION"
    local GRADING_SYSTEM="$DEFAULT_GRADING_SYSTEM"
    local INFRASTRUCTURE_TYPE="$DEFAULT_INFRASTRUCTURE"
    local ENVIRONMENT=""
    local FEATURES="standard"
    local DRY_RUN="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --region)
                EDUCATIONAL_REGION="$2"
                shift 2
                ;;
            --infrastructure)
                INFRASTRUCTURE_TYPE="$2"  
                shift 2
                ;;
            --grading-system)
                GRADING_SYSTEM="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --features)
                FEATURES="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate educational region
    if [[ ! "$EDUCATIONAL_REGION" =~ ^(global|africa|cameroon|usa|europe)$ ]]; then
        log_error "Invalid educational region: $EDUCATIONAL_REGION"
        show_usage
        exit 1
    fi
    
    echo -e "${BLUE}🎓 AcademyAxis Educational Platform Setup${NC}"
    echo "========================================"
    echo ""
    echo "Educational Region: $EDUCATIONAL_REGION"
    echo "Grading System: $GRADING_SYSTEM"
    echo "Infrastructure Type: $INFRASTRUCTURE_TYPE"
    echo "Environment: ${ENVIRONMENT:-all}"
    echo "Features: $FEATURES"
    echo "Dry Run: $DRY_RUN"
    echo ""
    
    check_prerequisites
    
    # Setup projects based on environment
    if [[ "$ENVIRONMENT" == "all" ]] || [[ -z "$ENVIRONMENT" ]]; then
        for PROJECT_ID in "${!EDUCATIONAL_PROJECTS[@]}"; do
            if [[ "$INFRASTRUCTURE_TYPE" == "cameroon237" ]] && [[ "$PROJECT_ID" == *"237"* ]]; then
                setup_educational_project $PROJECT_ID ${EDUCATIONAL_PROJECTS[$PROJECT_ID]} $EDUCATIONAL_REGION $GRADING_SYSTEM
            elif [[ "$INFRASTRUCTURE_TYPE" == "existing" ]] && [[ "$PROJECT_ID" != *"237"* ]]; then
                setup_educational_project $PROJECT_ID ${EDUCATIONAL_PROJECTS[$PROJECT_ID]} $EDUCATIONAL_REGION $GRADING_SYSTEM
            fi
        done
    else
        # Setup specific environment
        for PROJECT_ID in "${!EDUCATIONAL_PROJECTS[@]}"; do
            if [[ "$PROJECT_ID" == *"$ENVIRONMENT"* ]]; then
                if [[ "$INFRASTRUCTURE_TYPE" == "cameroon237" ]] && [[ "$PROJECT_ID" == *"237"* ]]; then
                    setup_educational_project $PROJECT_ID ${EDUCATIONAL_PROJECTS[$PROJECT_ID]} $EDUCATIONAL_REGION $GRADING_SYSTEM
                elif [[ "$INFRASTRUCTURE_TYPE" == "existing" ]] && [[ "$PROJECT_ID" != *"237"* ]]; then
                    setup_educational_project $PROJECT_ID ${EDUCATIONAL_PROJECTS[$PROJECT_ID]} $EDUCATIONAL_REGION $GRADING_SYSTEM
                fi
            fi
        done
    fi
    
    echo ""
    log_success "🎉 AcademyAxis Educational Platform setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. 🏫 Test school onboarding process"
    echo "2. 👨‍🏫 Configure teacher accounts and permissions"  
    echo "3. 👨‍👩‍👧‍👦 Set up parent portal access"
    echo "4. 📚 Upload initial curriculum content"
    echo "5. 🧪 Run end-to-end educational workflow tests"
}

# Export DRY_RUN for use in functions
export DRY_RUN

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi