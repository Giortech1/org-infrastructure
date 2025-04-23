# AcademyAxis.io Infrastructure

This repository contains the Infrastructure as Code (IaC) for the AcademyAxis.io organization. It manages the GCP environment for three independent applications:

1. **giortech** - Public-facing website
2. **waspwallet** - Mobile application
3. **AcademyAxis** - Mobile application and web platform

## Infrastructure Architecture

The infrastructure follows a multi-environment approach with isolated projects for each application and environment:

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

## GCP Services Used

- **Compute**: Cloud Run (fully managed, scales to zero)
- **Storage**: Cloud Storage (for static content)
- **Database**: Firestore (native mode)
- **Secrets**: Secret Manager
- **Networking**: Cloud DNS + HTTPS Load Balancer
- **Monitoring**: Cloud Monitoring + Logging (basic tier)
- **CI/CD**: GitHub Actions

## Repository Structure

```
org-infrastructure/
├── .github/
│   └── workflows/           # GitHub Actions workflows for deployment
│       ├── deploy.yml       # Main deployment workflow
│       └── deploy-lb-dns.yml # Load balancer and DNS setup workflow
│
├── scripts/                 # Utility scripts
│   ├── setup-lb-dns.sh      # Script for setting up load balancer and DNS
│   └── setup-workload-identity.sh # Script for setting up GitHub Actions auth
│
├── terraform/               # Terraform configurations
│   └── organization/
│       ├── giortech/        # giortech application infrastructure
│       │   ├── dev/         # Development environment
│       │   ├── uat/         # UAT environment
│       │   ├── prod/        # Production environment
│       │   ├── main.tf      # Main Terraform configuration
│       │   ├── variables.tf # Variable definitions
│       │   └── modules/     # Reusable Terraform modules
│       │       ├── networking/ # Networking configuration
│       │       └── dns/     # DNS configuration
│       │
│       ├── waspwallet/      # waspwallet application infrastructure (similar structure)
│       └── academyaxis/     # academyaxis application infrastructure (similar structure)
│
└── README.md                # This README file
```

## Deployment Strategy

The infrastructure uses a branch-based deployment strategy:

- `dev` branch → Development environment
- `uat` branch → UAT environment
- `main` branch → Production environment

Each application has its own GitHub repository with CI/CD workflows that deploy to the corresponding environments.

## Cost Management

The infrastructure is designed to stay within a monthly budget of $300 USD total. Budget alerts are configured at multiple thresholds (50%, 75%, 90%, 100%) to ensure cost control.

### Budget Allocation

| Application | Environment | Budget (USD) |
|-------------|------------|--------------|
| giortech    | dev        | $50          |
|             | uat        | $50          |
|             | prod       | $100         |
| waspwallet  | dev        | $25          |
|             | uat        | $25          |
|             | prod       | $50          |
| academyaxis | dev        | $10          |
|             | uat        | $15          |
|             | prod       | $25          |
| **Total**   |            | **$300**     |

## Getting Started

### Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+)
- [GitHub CLI](https://cli.github.com/) (optional, for workflow management)

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/giortech1/org-infrastructure.git
   cd org-infrastructure
   ```

2. **Set up the GCP organization**:
   Follow the [GCP organization setup guide](https://cloud.google.com/resource-manager/docs/creating-managing-organization) to create the AcademyAxis.io organization.

3. **Create the folder structure**:
   ```bash
   gcloud resource-manager folders create --display-name="giortech-folder" --organization=ORGANIZATION_ID
   gcloud resource-manager folders create --display-name="waspwallet-folder" --organization=ORGANIZATION_ID
   gcloud resource-manager folders create --display-name="academyaxis-folder" --organization=ORGANIZATION_ID
   ```

4. **Create projects**:
   ```bash
   # Example for giortech-dev-project
   gcloud projects create giortech-dev-project --folder=FOLDER_ID
   gcloud billing projects link giortech-dev-project --billing-account=BILLING_ACCOUNT_ID
   ```

5. **Set up Workload Identity Federation for GitHub Actions**:
   ```bash
   ./scripts/setup-workload-identity.sh
   ```

### Deploying Infrastructure

For each application and environment:

1. **Initialize Terraform**:
   ```bash
   cd terraform/organization/giortech/dev
   terraform init
   ```

2. **Apply Terraform configuration**:
   ```bash
   terraform apply
   ```

### Manual Deployment (if needed)

You can manually trigger the deployment workflow from GitHub:

1. Go to the Actions tab in the repository
2. Select the "Deploy Application" workflow
3. Click "Run workflow"
4. Select the application and environment
5. Click "Run workflow"

## Troubleshooting

### Common Issues

#### Terraform Validation Errors

If you encounter errors during `terraform validate` like:

```
Error: Missing resource instance key
```

This usually indicates that you're trying to reference a resource with a `count` attribute without specifying the index. Fix this by:

1. If you intended to use `count`, reference the resource with an index:
   ```terraform
   resource "google_cloud_run_service" "app_service" {
     count = 3
     # ...
   }
   
   resource "google_cloud_run_service_iam_member" "public_access" {
     count    = 3
     location = google_cloud_run_service.app_service[count.index].location
     service  = google_cloud_run_service.app_service[count.index].name
     # ...
   }
   ```

2. If you didn't intend to use `count`, remove the attribute:
   ```terraform
   resource "google_cloud_run_service" "app_service" {
     # no count attribute
     # ...
   }
   ```

#### GitHub Actions Authentication Issues

If GitHub Actions fails to authenticate with GCP, check:

1. The Workload Identity Federation configuration: 
   ```bash
   gcloud iam workload-identity-pools providers describe github-provider \
     --project=PROJECT_ID \
     --location=global \
     --workload-identity-pool=github-pool
   ```

2. The service account permissions:
   ```bash
   gcloud projects get-iam-policy PROJECT_ID
   ```

## Maintenance and Monitoring

### Budget Monitoring

1. Set up email notifications for budget alerts
2. Regularly check the [GCP Billing Reports](https://console.cloud.google.com/billing)
3. Use the [GCP Cost Management dashboard](https://console.cloud.google.com/cost-management/dashboard) to identify cost outliers

### Infrastructure Updates

1. Always test changes in the dev environment first
2. Use Terraform's plan feature to review changes before applying:
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

3. Maintain a change log for significant infrastructure updates

## Contributing

1. Create a feature branch from `dev`
2. Make your changes
3. Open a pull request to merge your changes into `dev`
4. After testing in the dev environment, merge to `uat` and then to `main`

## License

This project is licensed under the MIT License - see the LICENSE file for details.
