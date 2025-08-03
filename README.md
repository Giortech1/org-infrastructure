# AcademyAxis.io Infrastructure & Multi-Tenant Platform

We manage the GCP environments for multiple independent applications through a consistent, environment-based approach with enhanced multi-tenant capabilities.

## 🏢 Applications

1. **giortech** - Public-facing website
2. **waspwallet** - Mobile application  
3. **academyaxis** - Mobile application and web platform (Global)
4. **academyaxis-237** - Multi-tenant platform (Cameroon-specific) ✨ **NEW**

## 🏗️ Infrastructure Architecture

### Standard Applications
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
    ├── academyaxis-folder
    │   ├── academyaxis-dev-project
    │   ├── academyaxis-uat-project
    │   └── academyaxis-prod-project
    └── academyaxis237-folder ✨ NEW
        ├── academyaxis-237-dev-project
        ├── academyaxis-237-uat-project
        └── academyaxis-237-prod-project
```

### Multi-Tenant Platform (AcademyAxis-237)

The AcademyAxis-237 platform provides enhanced multi-tenant capabilities:

- **🌍 Regional Support**: Africa, Cameroon-specific configurations
- **🏫 School Isolation**: Cross-school parent support with data isolation
- **💰 Payment Integration**: Orange Money, MTN Mobile Money, Express Union
- **📱 Communication**: Africa's Talking SMS, SendGrid email
- **🗣️ Bilingual Support**: French-Cameroon (fr-CM), English-Cameroon (en-CM)
- **💲 Currency**: Central African Franc (XAF)
- **⏰ Timezone**: Africa/Douala

## 📁 Repository Structure

```
org-infrastructure/
├── .github/workflows/           # GitHub Actions workflows
│   ├── app-deploy.yml           # Generic application deployment
│   ├── branch-deploy.yml        # Branch-based infrastructure deployment
│   ├── network-deploy.yml       # Network infrastructure deployment
│   └── deploy-academyaxis-multitenant.yml ✨ # NEW: Enhanced multi-tenant workflow
│
├── scripts/                     # Utility scripts
│   ├── domain-mapping.sh        # Script for mapping domains to services
│   ├── setup-lb-dns.sh          # Script for setting up load balancer and DNS
│   ├── setup-workload-identity.sh # Script for setting up GitHub Actions auth
│   └── setup-environment.sh ✨ # NEW: Enhanced setup with academyaxis-237
│
├── terraform/                   # Terraform configurations
│   ├── modules/                 # Reusable Terraform modules
│   │   ├── workload_identity/   # GitHub Actions authentication
│   │   └── network_infrastructure/ # Network configuration
│   │
│   └── organization/           # Organization-specific configurations
│       ├── giortech/           # giortech application infrastructure
│       ├── waspwallet/         # waspwallet application infrastructure
│       ├── academyaxis/        # academyaxis application infrastructure
│       └── academyaxis237/ ✨  # NEW: academyaxis-237 infrastructure
│           ├── dev/            # Development environment
│           ├── uat/            # UAT environment
│           └── prod/           # Production environment
│
└── .github/config/
    └── project-config.yml ✨    # UPDATED: Includes academyaxis237 config
```

## 🚀 Enhanced Deployment Workflows

### Single Multi-Tenant Workflow ✨ **NEW**

We now use a **single comprehensive workflow** (`deploy-academyaxis-multitenant.yml`) that handles:

#### **Automatic Branch-Based Deployments**
- ✅ Push to `develop` → Auto-deploy to **dev** environment
- ✅ Push to `uat` → Auto-deploy to **uat** environment  
- ✅ Push to `prod` → Auto-deploy to **prod** environment

#### **Manual Multi-Tenant Control**
- 🎛️ **Manual dispatch** with full control over:
  - Environment (dev/uat/prod)
  - Project type (existing academyaxis vs academyaxis237)
  - Deployment region (africa/cameroon/global)
  - Force rebuild option

### Branch to Environment Mapping

| Branch   | Environment | Standard Projects | Multi-Tenant Projects (237) |
|----------|-------------|-------------------|----------------------------|
| develop  | dev         | academyaxis-dev-project | academyaxis-237-dev-project |
| uat      | uat         | academyaxis-uat-project | academyaxis-237-uat-project |
| prod     | prod        | academyaxis-prod-project | academyaxis-237-prod-project |

## 🎯 How to Deploy

### **Automatic Deployment (Branch-Based)**
```bash
# Deploy to development
git checkout develop
git push origin develop  # → Automatically deploys to dev environment

# Deploy to UAT
git checkout uat
git push origin uat      # → Automatically deploys to uat environment

# Deploy to production
git checkout prod
git push origin prod     # → Automatically deploys to prod environment
```

### **Manual Deployment (Multi-Tenant Control)**
1. Go to GitHub Actions
2. Select "Deploy AcademyAxis Multi-Tenant Platform"
3. Click "Run workflow"
4. Choose your options:
   - **Environment**: dev/uat/prod
   - **Target Project**: 
     - `existing` → Uses standard academyaxis projects
     - `academyaxis237` → Uses Cameroon-specific projects with multi-tenant features
   - **Deployment Region**: africa/cameroon/global
5. Click "Run workflow"

## 🌍 Multi-Tenant Features

### **When Using AcademyAxis-237 Projects:**

#### **Regional Configuration**
- **Default Language**: French-Cameroon (fr-CM)
- **Supported Languages**: fr-CM, en-CM
- **Currency**: Central African Franc (XAF)
- **Timezone**: Africa/Douala

#### **Payment Providers**
- Orange Money
- MTN Mobile Money
- Express Union

#### **Communication Providers**
- **SMS**: Africa's Talking
- **Email**: SendGrid

#### **Educational Features**
- Multi-school tenant isolation
- Cross-school parent access
- Regional compliance features
- Bilingual platform support

## 🛠️ Infrastructure Services

### **Compute & Hosting**
- **Cloud Run** (fully managed, scales to zero)
- **Artifact Registry** (Docker container storage)

### **Data & Storage**
- **Cloud Storage** (for static content and media)
- **Firestore** (native mode for application data)
- **Secret Manager** (for API keys and credentials)

### **Networking & Security**
- **Cloud DNS** + **HTTPS Load Balancer**
- **Cloud Armor** (WAF protection for production)
- **SSL Certificates** (managed certificates)

### **Monitoring & Operations**
- **Cloud Monitoring** + **Logging** (with cost-optimized retention)
- **Budget Controls** (per-project spending limits)
- **Health Checks** (automated service monitoring)

### **CI/CD**
- **GitHub Actions** (with Workload Identity Federation)
- **Terraform** (Infrastructure as Code)

## 💰 Cost Management

### **Budget Allocation**
- **Total Organization Budget**: $300/month
- **AcademyAxis Allocation**: $150/month
- **AcademyAxis-237 Allocation**: $200/month

| Application | Dev | UAT | Prod | Total |
|-------------|-----|-----|------|-------|
| **AcademyAxis** | $25 | $25 | $100 | $150 |
| **AcademyAxis-237** | $50 | $50 | $100 | $200 |

### **Cost Optimization Features**
- Auto-scaling to zero for dev/uat environments
- Limited log retention (7 days dev/uat, 30 days prod)
- Log filtering to exclude health checks
- Lifecycle rules for artifact cleanup

## 🔧 Development Workflow

### **Standard Development Flow**
```bash
# 1. Create feature branch
git checkout develop
git checkout -b feature/new-feature

# 2. Make changes and test locally
npm start  # or your local development command

# 3. Push feature branch (no auto-deployment)
git push origin feature/new-feature

# 4. Create PR to develop
# After PR approval and merge → Auto-deploys to dev

# 5. Promote to UAT
git checkout uat
git merge develop
git push origin uat  # → Auto-deploys to uat

# 6. Promote to Production
git checkout prod
git merge uat
git push origin prod  # → Auto-deploys to prod
```

### **Multi-Tenant Testing Flow**
```bash
# Test with standard academyaxis projects
git push origin develop  # → Uses academyaxis-dev-project

# Test with multi-tenant academyaxis-237 projects
# Use manual workflow dispatch:
# 1. Go to GitHub Actions
# 2. Select "Deploy AcademyAxis Multi-Tenant Platform"
# 3. Choose: Environment=dev, Target Project=academyaxis237
```

## 🔐 Authentication & Security

### **Workload Identity Federation**
Each project uses Workload Identity Federation for secure GitHub Actions authentication:

| Project | Project Number | Workload Identity Provider |
|---------|----------------|----------------------------|
| academyaxis-dev-project | 1052274887859 | projects/1052274887859/locations/global/workloadIdentityPools/github-pool/providers/github-provider |
| academyaxis-uat-project | 415071431590 | projects/415071431590/locations/global/workloadIdentityPools/github-pool/providers/github-provider |
| academyaxis-prod-project | 552816176477 | projects/552816176477/locations/global/workloadIdentityPools/github-pool/providers/github-provider |
| academyaxis-237-dev-project | 425169602074 | projects/425169602074/locations/global/workloadIdentityPools/github-pool/providers/github-provider |
| academyaxis-237-uat-project | 523018028271 | projects/523018028271/locations/global/workloadIdentityPools/github-pool/providers/github-provider |
| academyaxis-237-prod-project | 684266177356 | projects/684266177356/locations/global/workloadIdentityPools/github-pool/providers/github-provider |

### **Service Accounts**
Each project has a dedicated service account:
- **Pattern**: `github-actions-sa@{project-id}.iam.gserviceaccount.com`
- **Permissions**: Cloud Run Admin, Artifact Registry Admin, Storage Admin

## 🧪 Testing & Validation

### **Health Checks**
All deployments include automatic health checks:
- Service connectivity tests
- Multi-tenant configuration validation (for academyaxis-237)
- Regional settings verification (for academyaxis-237)

### **Environment-Specific Testing**
- **Dev**: Feature development and unit testing
- **UAT**: User acceptance testing and integration testing
- **Prod**: Live environment with monitoring and alerting

## 🆘 Troubleshooting

### **Common Issues**

#### **1. GitHub Actions Authentication**
If workflows fail with authentication errors:
- Verify Workload Identity Federation is configured
- Check service account permissions
- Ensure repository name matches configuration

#### **2. Multi-Tenant Configuration**
If multi-tenant features aren't working:
- Verify `MULTI_TENANT=true` environment variable is set
- Check regional configuration (REACT_APP_REGION)
- Validate language and currency settings

#### **3. Branch Deployment Issues**
If automatic deployments don't trigger:
- Ensure you're pushing to `develop`, `uat`, or `prod` branches
- Check workflow file is named correctly
- Verify GitHub Actions are enabled for the repository

### **Monitoring & Logs**
- **GCP Console**: https://console.cloud.google.com/
- **Cloud Run Logs**: https://console.cloud.google.com/run
- **Monitoring Dashboards**: https://console.cloud.google.com/monitoring

## 🔗 Useful Links

### **Project Management**
- **GCP Organization**: https://console.cloud.google.com/iam-admin/iam?organizationId=126324232219
- **Billing**: https://console.cloud.google.com/billing
- **GitHub Repository**: https://github.com/Giortech1/org-infrastructure

### **Application URLs**
- **AcademyAxis Dev**: https://academyaxis-dev-[hash]-uc.a.run.app
- **AcademyAxis UAT**: https://academyaxis-uat-[hash]-uc.a.run.app
- **AcademyAxis Prod**: https://academyaxis-prod-[hash]-uc.a.run.app
- **AcademyAxis-237 Dev**: https://academyaxis237-dev-[hash]-uc.a.run.app
- **AcademyAxis-237 UAT**: https://academyaxis237-uat-[hash]-uc.a.run.app
- **AcademyAxis-237 Prod**: https://academyaxis237-prod-[hash]-uc.a.run.app

## 🤝 Contributing

1. Create a feature branch from `develop`
2. Make your changes following the coding standards
3. Test locally and with dev environment
4. Create a pull request to merge into `develop`
5. After testing in dev, promote through uat to prod
6. For multi-tenant features, test with both project types

## 📧 Support

For support and questions:
- **Infrastructure Issues**: Create an issue in this repository
- **Application Issues**: Contact the respective application team
- **Multi-Tenant Platform**: support@academyaxis.io
- **Billing/Cost Issues**: admin@giortech.com

---

**AcademyAxis** - Empowering education through technology 🎓  
**Multi-Tenant Platform** - Serving schools across Africa 🌍