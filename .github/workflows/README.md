# GitHub Workflows for AcademyAxis.io

This document explains the GitHub workflows used for infrastructure and application deployment in the AcademyAxis.io organization.

## Overview

The workflows are designed to support:
- Multiple applications (giortech, waspwallet, academyaxis)
- Multiple environments (dev, uat, prod)
- Both manual and automated deployments
- Branch-based deployments (develop → dev, uat → uat, main → prod)
- Separate network infrastructure deployment

## Available Workflows

### 1. `network-deploy.yml` - Network Infrastructure Deployment

This workflow manages the deployment of network infrastructure including load balancers, DNS, certificates, and security policies.

**Trigger**: Manual workflow dispatch
**Parameters**:
- `environment`: Environment to deploy to (dev, uat, prod)
- `application`: Application to configure (giortech, waspwallet, academyaxis)
- `action`: Action to perform (plan, apply, destroy)

**What it does**:
- Sets up project variables based on inputs
- Creates or updates Terraform configuration for network infrastructure
- Applies the Terraform configuration
- Verifies the deployment

### 2. `branch-deploy.yml` - Automated Branch-Based Infrastructure Deployment

This workflow automatically deploys application infrastructure when changes are pushed to specific branches.

**Trigger**: Push to develop, uat, or main branch
**What it does**:
- Determines environment based on branch (develop → dev, uat → uat, main → prod)
- Determines application based on repository name
- Sets up Terraform working directory
- Initializes and applies Terraform configurations

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

## Deployment Sequence

For a complete deployment of a new application:

1. First, deploy the base infrastructure using `branch-deploy.yml`
2. Then, deploy the network infrastructure using `network-deploy.yml`
3. Finally, deploy the application using `app-deploy.yml`

## Branch to Environment Mapping

| Branch   | Environment | Project Suffix |
|----------|-------------|----------------|
| develop  | dev         | -dev-project   |
| uat      | uat         | -uat-project   |
| main     | prod        | -prod-project  |

## Usage Examples

### Deploy network infrastructure for giortech production:

1. Go to the Actions tab in GitHub
2. Select "Network Infrastructure Deployment" workflow
3. Click "Run workflow"
4. Select:
   - Environment: prod
   - Application: giortech
   - Action: apply
5. Click "Run workflow"

### Deploy application changes:

Simply push to the appropriate branch:
- For development: Push to `develop` branch
- For UAT testing: Push to `uat` branch
- For production: Push to `main` branch

The application will be automatically built and deployed to the corresponding environment.