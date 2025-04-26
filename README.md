# AcademyAxis.io Infrastructure

This repository contains the Infrastructure as Code (IaC) for the AcademyAxis.io organization. We manage the GCP environments for three independent applications through a consistent, environment-based approach.

## Applications

1. **giortech** - Public-facing website
2. **waspwallet** - Mobile application
3. **academyaxis** - Mobile application and web platform

## Infrastructure Architecture

Each application has isolated projects for dev, UAT, and production environments:

```
Organization: AcademyAxis.io
|
└── AcademyAxis.io (Root Org Folder)
    ├── giortech-folder
    │   ├── giortech-dev-project
    │   ├── giortech-uat-project
    │   └── giortech-prod-project
    ├── waspwallet-folder
    │   ├── waspwallet-dev-project
    │   ├── waspwallet-uat-project
    │   └── waspwallet-prod-project
    └── academyaxis-folder
        ├── academyaxis-dev-project
        ├── academyaxis-uat-project
        └── academyaxis-prod-project
```

## Repository Structure

```
org-infrastructure/
├── .github/workflows/           # GitHub Actions workflows
│   ├── app-deploy.yml           # Generic application deployment
│   ├── branch-deploy.yml        # Branch-based infrastructure deployment
│   ├── network-deploy.yml       # Network infrastructure deployment
│   ├── deploy-dev.yml           # Application-specific dev deployment
│   ├── deploy-uat.yml           # Application-specific UAT deployment
│   └── deploy-prod.yml          # Application-specific production deployment
│
├── scripts/                     # Utility scripts
│   ├── domain-mapping.sh        # Script for mapping domains to services
│   ├── setup-lb-dns.sh          # Script for setting up load balancer and DNS
│   └── setup-workload-identity.sh # Script for setting up GitHub Actions auth
│
├── terraform/                   # Terraform configurations
│   ├── modules/                 # Reusable Terraform modules
│   │   ├── workload_identity/   # GitHub Actions authentication
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   └── network_infrastructure/  # Network configuration
│   │       ├── cert/           # SSL certificates for non-prod environments
│   │       ├── dns.tf          # DNS configuration
│   │       ├── load_balancer.tf # Load balancer configuration
│   │       ├── main.tf         # Main configuration
│   │       ├── monitoring.tf   # Monitoring configuration
│   │       ├── outputs.tf      # Output variables
│   │       ├── security.tf     # Cloud Armor WAF configuration
│   │       └── variables.tf    # Input variables
│   │
│   └── organization/           # Organization-specific configurations
│       ├── giortech/           # giortech application infrastructure
│       │   ├── dev/            # Development environment
│       │   ├── uat/            # UAT environment
│       │   ├── prod/           # Production environment
│       │   ├── main.tf         # Main Terraform configuration
│       │   └── variables.tf    # Variable definitions
│       │
│       ├── waspwallet/         # waspwallet application infrastructure
│       └── academyaxis/        # academyaxis application infrastructure
```

## Understanding Our Workflow Types

### 1. Environment-Specific Workflows

These workflows deploy applications to specific environments with pre-configured settings:

- **deploy-dev.yml**: Deploys to development environment
- **deploy-uat.yml**: Deploys to UAT environment
- **deploy-prod.yml**: Deploys to production environment

**When to use**: For application code deployments when you want to target a specific environment.

Example: Deploying a new version of the giortech website to production.

```yaml
# This is handled by deploy-prod.yml
name: Deploy to Production

env:
  PROJECT_ID: giortech-prod-project
  REGION: us-central1
  SERVICE_NAME: giortech-prod
  # Pre-configured with the proper service account and identity provider
```

### 2. Generic Infrastructure Workflows

These workflows handle infrastructure deployment with dynamic environment detection:

- **app-deploy.yml**: Deploys applications to Cloud Run based on the branch or manual selection
- **branch-deploy.yml**: Automatically deploys infrastructure when pushing to specific branches
- **network-deploy.yml**: Manages network infrastructure (load balancers, DNS, certificates)

**When to use**: For infrastructure deployments or when you need branch-based environment targeting.

Example: Updating load balancer configuration for all environments.

## Branch to Environment Mapping

| Branch   | Environment | Project Suffix |
|----------|-------------|----------------|
| develop  | dev         | -dev-project   |
| uat      | uat         | -uat-project   |
| prod     | prod        | -prod-project  |

## Deployment Workflows

### 1. Deploying Application Code

Choose the appropriate method based on your needs:

#### Option 1: Branch-based deployment

1. Make changes to your application code
2. Push to the corresponding branch:
   - `develop` → deploys to development
   - `uat` → deploys to UAT
   - `prod` → deploys to production

The workflow will automatically detect the environment based on the branch.

#### Option 2: Environment-specific workflow

1. Go to the Actions tab in GitHub
2. Select the appropriate deployment workflow:
   - For development: Select "Deploy to Dev"
   - For UAT: Select "Deploy to UAT"
   - For production: Select "Deploy to Production"
3. Click "Run workflow"
4. Select the branch containing your code changes
5. Click "Run workflow"

### 2. Deploying Network Infrastructure

Network infrastructure (load balancers, DNS, certificates) is managed separately from application code.

1. Go to the Actions tab in GitHub
2. Select "Network Infrastructure Deployment"
3. Click "Run workflow"
4. Select:
   - Environment: (dev, uat, prod)
   - Application: (giortech, waspwallet, academyaxis)
   - Action: (plan, apply, destroy)
5. Click "Run workflow"

## Development Workflow

1. Create a feature branch from `develop`
2. Make your changes
3. Push to your feature branch
4. Create a pull request to merge into `develop`
5. After testing in the development environment, create a pull request to merge to `uat`
6. After UAT approval, create a pull request to merge to `prod`

## Troubleshooting

### Common Issues

#### 1. Terraform Validation Errors

If you encounter errors during Terraform validation, check:
- Module paths are correct
- Required APIs are enabled in your GCP project
- Service account has necessary permissions

#### 2. GitHub Actions Authentication Issues

If the workflow fails to authenticate with GCP:
- Check the Workload Identity Federation configuration
- Verify the repository name and organization match what's configured in GCP
- Ensure the service account has the necessary permissions

#### 3. Deploy Workflow Failures

If application deployment fails:
- Check if the Dockerfile exists and is valid
- Ensure Cloud Run API is enabled
- Verify the service account has Cloud Run Admin role

## GCP Services Used

- **Compute**: Cloud Run (fully managed, scales to zero)
- **Storage**: Cloud Storage (for static content)
- **Database**: Firestore (native mode)
- **Secrets**: Secret Manager
- **Networking**: Cloud DNS + HTTPS Load Balancer
- **Monitoring**: Cloud Monitoring + Logging (basic tier)
- **CI/CD**: GitHub Actions

## Contributing

1. Create a feature branch from `develop`
2. Make your changes
3. Open a pull request to merge your changes into `develop`
4. After testing in the dev environment, merge to `uat` and then to `prod`