cat > terraform/modules/educational_platform/README.md << 'EOF'
# Educational Platform Module

This module creates the infrastructure for the AcademyAxis Educational Platform with Bitrix24-inspired multi-tenant architecture.

## Features

- Multi-tenant school isolation
- Academic schedule-based scaling
- Cross-school parent functionality
- Regional educational compliance
- Educational monitoring and alerting

## Usage

```hcl
module "educational_platform" {
  source = "../../modules/educational_platform"
  
  project_id              = "your-project-id"
  region                  = "us-central1"
  environment             = "dev"
  educational_region      = "global"
  
  # Educational configuration
  supported_languages     = ["en-US"]
  grading_system         = "flexible"
  payment_providers      = ["stripe"]
  sms_provider           = "twilio"
  
  # Budget controls
  create_budget          = true
  budget_amount          = 50
  billing_account_id     = "your-billing-account-id"
  
  # Secrets
  school_onboarding_key  = "your-secret-key"
}