#!/bin/bash
# Script to add missing permissions to service accounts

# Fix Python path for gcloud - use the actual Python installation
export CLOUDSDK_PYTHON="/c/Users/Roman Gates/AppData/Local/Programs/Python/Python313/python.exe"
# Alternative: you can also try this path format
# export CLOUDSDK_PYTHON="C:\\Users\\Roman Gates\\AppData\\Local\\Programs\\Python\\Python313\\python.exe"

PROJECTS=("giortech-dev-project" "giortech-uat-project" "giortech-prod-project")

for PROJECT_ID in "${PROJECTS[@]}"; do
    echo "Adding missing permissions to $PROJECT_ID..."
    SA_EMAIL="github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
    # Check if service account exists
    if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo "Adding logging permissions to $SA_EMAIL..."
        # Add missing logging roles
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_EMAIL" \
            --role="roles/logging.bucketWriter" \
            --quiet
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_EMAIL" \
            --role="roles/logging.configWriter" \
            --quiet
        echo "‚úÖ Updated permissions for $PROJECT_ID"
    else
        echo "‚ö†Ô∏è Service account not found in $PROJECT_ID"
    fi
done
echo "Ìæâ Permission updates completed!"
