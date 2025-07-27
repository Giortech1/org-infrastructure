#!/bin/bash
# Debug and fix workload identity binding for waspwallet-dev-project

set -e

PROJECT_ID="waspwallet-dev-project"
PROJECT_NUMBER="260301647000"
SERVICE_ACCOUNT="github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"
GITHUB_ORG="giortech1"
GITHUB_REPO="org-infrastructure"

echo "�� Debugging Workload Identity binding for $PROJECT_ID"
echo "======================================================="

# Set project
gcloud config set project $PROJECT_ID

echo "1️⃣ Checking workload identity pool..."
if gcloud iam workload-identity-pools describe github-pool --location=global --project=$PROJECT_ID >/dev/null 2>&1; then
    echo "✅ Workload Identity Pool exists"
    
    # Show pool details
    echo "Pool details:"
    gcloud iam workload-identity-pools describe github-pool --location=global --project=$PROJECT_ID --format="yaml(name,state,description)"
else
    echo "❌ Workload Identity Pool does not exist. Creating..."
    gcloud iam workload-identity-pools create github-pool \
        --project=$PROJECT_ID \
        --location=global \
        --display-name="GitHub Actions Pool" \
        --description="Workload Identity Pool for GitHub Actions"
    echo "✅ Workload Identity Pool created"
fi

echo ""
echo "2️⃣ Checking workload identity provider..."
if gcloud iam workload-identity-pools providers describe github-provider \
    --workload-identity-pool=github-pool \
    --location=global \
    --project=$PROJECT_ID >/dev/null 2>&1; then
    echo "✅ Workload Identity Provider exists"
    
    # Show provider details
    echo "Provider details:"
    gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --project=$PROJECT_ID \
        --format="yaml(name,state,attributeCondition,attributeMapping)"
else
    echo "❌ Workload Identity Provider does not exist. Creating..."
    gcloud iam workload-identity-pools providers create-oidc github-provider \
        --project=$PROJECT_ID \
        --location=global \
        --workload-identity-pool=github-pool \
        --display-name="GitHub Provider" \
        --description="GitHub Actions OIDC Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-condition="assertion.repository_owner == '$GITHUB_ORG'"
    echo "✅ Workload Identity Provider created"
fi

echo ""
echo "3️⃣ Checking current workload identity bindings on service account..."
echo "Current IAM policy for service account:"
gcloud iam service-accounts get-iam-policy $SERVICE_ACCOUNT --project=$PROJECT_ID || echo "No policy found"

echo ""
echo "4️⃣ Adding workload identity bindings..."

# Remove any existing bindings first to avoid conflicts
echo "Removing any existing workload identity bindings..."
gcloud iam service-accounts remove-iam-policy-binding $SERVICE_ACCOUNT \
    --project=$PROJECT_ID \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/$GITHUB_ORG/$GITHUB_REPO" \
    --quiet || echo "No existing repository binding to remove"

gcloud iam service-accounts remove-iam-policy-binding $SERVICE_ACCOUNT \
    --project=$PROJECT_ID \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository_owner/$GITHUB_ORG" \
    --quiet || echo "No existing repository owner binding to remove"

# Add fresh bindings
echo "Adding fresh workload identity bindings..."

# Binding for specific repository
echo "  Adding binding for repository: $GITHUB_ORG/$GITHUB_REPO"
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT \
    --project=$PROJECT_ID \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/$GITHUB_ORG/$GITHUB_REPO" \
    --quiet

# Binding for repository owner (broader access)
echo "  Adding binding for repository owner: $GITHUB_ORG"
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT \
    --project=$PROJECT_ID \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository_owner/$GITHUB_ORG" \
    --quiet

echo ""
echo "5️⃣ Verifying final workload identity configuration..."
echo "Service account IAM policy after fix:"
gcloud iam service-accounts get-iam-policy $SERVICE_ACCOUNT --project=$PROJECT_ID

echo ""
echo "Expected Workload Identity Provider in GitHub Actions:"
echo "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"

echo ""
echo "Expected Service Account in GitHub Actions:"
echo "$SERVICE_ACCOUNT"

echo ""
echo "✅ Workload Identity configuration completed!"
echo ""
echo "��� Key things to verify in your GitHub Actions workflow:"
echo "  1. Workload Identity Provider: projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
echo "  2. Service Account: $SERVICE_ACCOUNT"
echo "  3. Repository name in GitHub: $GITHUB_ORG/$GITHUB_REPO"
echo ""
echo "⏱️  Wait 5-10 minutes for changes to propagate, then re-run the workflow."
