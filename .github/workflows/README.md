# GitHub Workflows for AcademyAxis.io

This document explains the GitHub workflows used for infrastructure and application deployment in the AcademyAxis.io organization.

## Overview

The workflows are designed to support:
- Multiple applications (giortech, waspwallet, academyaxis)
- Multiple environments (dev, uat, prod)
- Both manual and automated deployments
- Branch-based deployments (develop → dev, uat → uat, main → prod)

## Available Workflows

### 1. `deploy-lb-dns.yml` - Manual Load Balancer and DNS Setup

This workflow is used to manually configure Load Balancer and DNS settings for an application in a specific environment.

**Trigger**: Manual workflow dispatch
**Parameters**:
- `environment`: Environment to deploy to (dev, uat, prod)
- `application`: Application to configure (giortech, waspwallet, academyaxis)

**What it does**:
- Sets up project variables based on inputs
- Gets Workload Identity configuration from Terraform
- Authenticates to Google Cloud
- Executes the Load Balancer and DNS setup script

### 2. `branch-deploy.yml` - Automated Branch-Based Infrastructure Deployment

This workflow automatically deploys infrastructure when changes are pushed to specific branches.

**Trigger**: Push to develop, uat, or main branch
**What it does**:
- Determines environment based on branch (develop → dev, uat → uat, main → prod)
- Determines application based on repository name
- Sets up Terraform working directory
- Initializes and applies Terraform configurations
- Sets up Load Balancer and DNS

### 3. `app-deploy.yml` - Application Deployment

This workflow builds and deploys application containers to Cloud Run.

**Trigger**: 
- Push to develop, uat, or main branch
- Manual workflow dispatch

**What it does**:
- Determines environment and application context
- Gets Workload Identity configuration
- Builds a container image
- Deploys the container to Cloud Run
- Runs post-deployment tests

## Branch to Environment Mapping

| Branch   | Environment | Project Suffix |
|----------|-------------|----------------|
| develop  | dev         | -dev-project   |
| uat      | uat         | -uat-project   |
| main     | prod        | -prod-project  |

## Directory Structure

The workflows expect the following directory structure:

```
org-infrastructure/
├── .github/
│   └── workflows/
│       ├── deploy-lb-dns.yml
│       ├── branch-deploy.yml
│       └── app-deploy.yml
│
├── scripts/
│   └── setup-lb-dns.sh
│
└── terraform/
    └── organization/
        ├── giortech/
        │   ├── dev/
        │   ├── uat/
        │   └── prod/
        ├── waspwallet/
        │   ├── dev/
        │   ├── uat/
        │   └── prod/
        └── academyaxis/
            ├── dev/
            ├── uat/
            └── prod/
```

## Workload Identity

The workflows use Workload Identity Federation to authenticate with Google Cloud. Each project should have:
- A Workload Identity Pool named `github-pool`
- A Provider named `github-provider`
- A Service Account named `github-actions-sa`

## Usage Examples

### Setup Load Balancer and DNS for giortech production:

1. Go to the Actions tab in GitHub
2. Select "Deploy Load Balancer and DNS" workflow
3. Click "Run workflow"
4. Select:
   - Environment: prod
   - Application: giortech
5. Click "Run workflow"

### Deploy application changes:

Simply push to the appropriate branch:
- For development: Push to `develop` branch
- For UAT testing: Push to `uat` branch
- For production: Push to `main` branch

The application will be automatically built and deployed to the corresponding environment.

## Troubleshooting

### Common Issues:

1. **"Directory not found" error**:
   - Ensure the Terraform directory structure matches the expected pattern
   - Check that environment names in workflow inputs match directory names (dev, uat, prod)

2. **Authentication errors**:
   - Verify Workload Identity Federation is properly set up
   - Check that the GitHub repository has access to the service account

3. **Terraform errors**:
   - Try running Terraform locally with the same variables
   - Check that the Terraform state is properly initialized

## Maintenance

When adding a new application:
1. Create the folder structure in `terraform/organization/`
2. Set up Workload Identity for the new application's projects
3. Update application choices in workflow files if needed