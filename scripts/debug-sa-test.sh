#!/bin/bash
PROJECTS=("giortech-dev-project" "giortech-uat-project" "giortech-prod-project")
for PROJECT_ID in "${PROJECTS[@]}"; do
    echo "Testing $PROJECT_ID..."
    SA_EMAIL="github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
    echo "  SA_EMAIL: $SA_EMAIL"
    echo "  PROJECT_ID: $PROJECT_ID"
    
    # Test without redirection first
    echo "  Testing command without redirection:"
    gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID"
    echo "  Exit code: $?"
    echo "---"
done
