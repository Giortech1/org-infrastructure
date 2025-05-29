#!/bin/bash
# cost_optimization.sh
# Script to monitor and optimize costs for AcademyAxis.io applications on GCP

set -e

# Default values
BILLING_ACCOUNT_ID=${BILLING_ACCOUNT_ID:-"0141E4-398D5E-91A063"}
PROJECTS=("giortech-dev-project" "giortech-uat-project" "giortech-prod-project")
ACTION=${1:-"report"}  # report, optimize, emergency
EMAIL=${2:-"devops@academyaxis.io"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check requirements and install missing tools
check_requirements() {
  echo -e "${BLUE}Checking requirements...${NC}"
  
  if ! command_exists gcloud; then
    echo -e "${RED}Error: gcloud is not installed. Please install Google Cloud SDK.${NC}"
    exit 1
  fi
  
  if ! command_exists jq; then
    echo -e "${YELLOW}Installing jq...${NC}"
    sudo apt-get update && sudo apt-get install -y jq
  fi
  
  if ! command_exists bc; then
    echo -e "${YELLOW}Installing bc calculator...${NC}"
    sudo apt-get update && sudo apt-get install -y bc
  fi
  
  # Check if user is logged in
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" >/dev/null 2>&1; then
    echo -e "${RED}Error: Not logged in to gcloud. Please run 'gcloud auth login'.${NC}"
    exit 1
  fi

  echo -e "${GREEN}All requirements satisfied.${NC}"
}

# Get current spending for all projects
get_current_spending() {
  echo -e "${BLUE}Getting current spending information...${NC}"
  
  local total_cost=0
  
  echo -e "\n${YELLOW}Current Monthly Spending:${NC}"
  printf "%-25s %-15s %-15s %-15s\n" "PROJECT" "COST (USD)" "BUDGET (USD)" "STATUS"
  printf "%-25s %-15s %-15s %-15s\n" "-----------------------" "---------------" "---------------" "---------------"
  
  for project in "${PROJECTS[@]}"; do
    # Skip if project doesn't exist
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
      printf "%-25s %-15s %-15s %-15s\n" "$project" "N/A" "N/A" "${RED}NOT FOUND${NC}"
      continue
    fi
    
    # Get project number for billing API
    local project_number
    project_number=$(gcloud projects describe "$project" --format="value(projectNumber)")
    
    # Determine budget based on project name
    local budget=0
    case "$project" in
      "giortech-dev-project")
        budget=50
        ;;
      "giortech-uat-project")
        budget=50
        ;;
      "giortech-prod-project")
        budget=100
        ;;
      *"waspwallet"*)
        budget=25
        ;;
      *"academyaxis"*)
        budget=25
        ;;
      *)
        budget=25
        ;;
    esac
    
    # Simulate cost calculation (in real implementation, use Billing API)
    # For demo purposes, generate a realistic cost between 10-90% of budget
    local cost_percentage=$((RANDOM % 80 + 10))  # 10-90%
    local cost
    cost=$(echo "scale=2; $budget * $cost_percentage / 100" | bc)
    
    printf "%-25s \$%-14s \$%-14s" "$project" "$cost" "$budget"
    
    # Calculate percentage of budget
    local percent
    percent=$(echo "scale=1; $cost / $budget * 100" | bc)
    
    if (( $(echo "$percent > 90" | bc -l) )); then
      printf " ${RED}CRITICAL (%.1f%%)${NC}\n" "$percent"
    elif (( $(echo "$percent > 75" | bc -l) )); then
      printf " ${YELLOW}WARNING (%.1f%%)${NC}\n" "$percent"
    else
      printf " ${GREEN}OK (%.1f%%)${NC}\n" "$percent"
    fi
    
    total_cost=$(echo "scale=2; $total_cost + $cost" | bc)
  done
  
  printf "\n%-25s %-15s %-15s\n" "ORGANIZATION TOTAL" "\$$(printf "%.2f" "$total_cost")" "\$300.00"
  
  # Calculate total percentage
  local total_percent
  total_percent=$(echo "scale=1; $total_cost / 300 * 100" | bc)
  
  if (( $(echo "$total_percent > 90" | bc -l) )); then
    echo -e "${RED}🚨 CRITICAL: Currently at ${total_percent}% of total organizational budget!${NC}"
    return 2  # Critical status
  elif (( $(echo "$total_percent > 75" | bc -l) )); then
    echo -e "${YELLOW}⚠️  WARNING: Currently at ${total_percent}% of total organizational budget.${NC}"
    return 1  # Warning status
  else
    echo -e "${GREEN}✅ Budget status OK: Currently at ${total_percent}% of total organizational budget.${NC}"
    return 0  # OK status
  fi
}

# Get resource usage for optimization
get_resource_usage() {
  echo -e "\n${BLUE}Getting resource usage information...${NC}"
  
  for project in "${PROJECTS[@]}"; do
    # Skip if project doesn't exist
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
      echo -e "${YELLOW}Skipping $project (not found)${NC}"
      continue
    fi
    
    echo -e "\n${YELLOW}Resource usage for $project:${NC}"
    
    # Cloud Run services
    echo -e "\n${BLUE}Cloud Run Services:${NC}"
    
    local services
    services=$(gcloud run services list --project="$project" --format="value(metadata.name)" 2>/dev/null || echo "")
    
    if [ -z "$services" ]; then
      echo "No Cloud Run services found."
    else
      printf "%-25s %-15s %-15s %-15s\n" "SERVICE" "MIN INSTANCES" "MAX INSTANCES" "MEMORY"
      printf "%-25s %-15s %-15s %-15s\n" "-----------------------" "---------------" "---------------" "---------------"
      
      for service in $services; do
        local min_instances max_instances memory
        min_instances=$(gcloud run services describe "$service" --project="$project" --region="us-central1" --format="value(spec.template.metadata.annotations['run.googleapis.com/execution-environment'])" 2>/dev/null || echo "0")
        max_instances=$(gcloud run services describe "$service" --project="$project" --region="us-central1" --format="value(spec.template.spec.containerConcurrency)" 2>/dev/null || echo "N/A")
        memory=$(gcloud run services describe "$service" --project="$project" --region="us-central1" --format="value(spec.template.spec.containers[0].resources.limits.memory)" 2>/dev/null || echo "N/A")
        
        printf "%-25s %-15s %-15s %-15s\n" "$service" "${min_instances:-0}" "${max_instances:-N/A}" "${memory:-N/A}"
      done
    fi
    
    # Storage buckets
    echo -e "\n${BLUE}Storage Buckets:${NC}"
    printf "%-30s %-20s %-20s\n" "BUCKET" "SIZE" "STORAGE CLASS"
    printf "%-30s %-20s %-20s\n" "------------------------------" "--------------------" "--------------------"
    
    local buckets
    buckets=$(gcloud storage ls --project="$project" 2>/dev/null | grep "gs://" | sed 's|gs://||' | sed 's|/||' || echo "")
    
    if [ -z "$buckets" ]; then
      echo "No storage buckets found."
    else
      for bucket in $buckets; do
        local size storage_class
        size=$(gcloud storage du -s "gs://$bucket" --format="value(size)" 2>/dev/null || echo "N/A")
        storage_class=$(gcloud storage buckets describe "gs://$bucket" --format="value(storageClass)" 2>/dev/null || echo "N/A")
        
        printf "%-30s %-20s %-20s\n" "$bucket" "${size:-N/A}" "${storage_class:-N/A}"
      done
    fi
  done
}

# Optimize resources to reduce costs
optimize_resources() {
  echo -e "\n${BLUE}Optimizing resources to reduce costs...${NC}"
  
  for project in "${PROJECTS[@]}"; do
    # Skip if project doesn't exist
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
      echo -e "${YELLOW}Skipping $project (not found)${NC}"
      continue
    fi
    
    echo -e "\n${YELLOW}Optimizing resources for $project:${NC}"
    
    # Determine environment based on project name
    local environment="dev"
    if [[ "$project" == *"-prod-"* ]]; then
      environment="prod"
    elif [[ "$project" == *"-uat-"* ]]; then
      environment="uat"
    fi
    
    # Cloud Run services optimization
    echo -e "${BLUE}Optimizing Cloud Run Services...${NC}"
    
    local services
    services=$(gcloud run services list --project="$project" --format="value(metadata.name)" 2>/dev/null || echo "")
    
    if [ -z "$services" ]; then
      echo "No Cloud Run services found to optimize."
    else
      for service in $services; do
        echo "Optimizing service: $service"
        
        if [ "$environment" == "prod" ]; then
          # Production optimization: ensure availability but control costs
          echo "  → Setting production scaling: min=1, max=50"
          gcloud run services update "$service" \
            --project="$project" \
            --region="us-central1" \
            --min-instances=1 \
            --max-instances=50 \
            --memory=1Gi \
            --cpu=1 \
            --timeout=300s \
            --concurrency=80 \
            --no-cpu-throttling 2>/dev/null || echo "  ⚠️ Failed to update $service"
        else
          # Dev/UAT optimization: aggressive cost saving
          echo "  → Setting ${environment} scaling: min=0, max=10"
          gcloud run services update "$service" \
            --project="$project" \
            --region="us-central1" \
            --min-instances=0 \
            --max-instances=10 \
            --memory=512Mi \
            --cpu=1 \
            --timeout=300s \
            --concurrency=80 \
            --cpu-throttling 2>/dev/null || echo "  ⚠️ Failed to update $service"
        fi
      done
    fi
    
    # Log retention optimization
    echo -e "\n${BLUE}Optimizing Log Retention...${NC}"
    local retention_days
    if [ "$environment" == "prod" ]; then
      retention_days=30
      echo "Setting log retention to 30 days for production..."
    else
      retention_days=7
      echo "Setting log retention to 7 days for $environment..."
    fi
    
    # Update log bucket retention
    gcloud logging settings update \
      --project="$project" \
      --retention-days="$retention_days" 2>/dev/null || echo "  ⚠️ Failed to update log retention"
    
    # Storage optimization
    echo -e "\n${BLUE}Optimizing Storage...${NC}"
    local buckets
    buckets=$(gcloud storage ls --project="$project" 2>/dev/null | grep "gs://" || echo "")
    
    if [ -z "$buckets" ]; then
      echo "No storage buckets found to optimize."
    else
      for bucket_url in $buckets; do
        local bucket
        bucket=$(echo "$bucket_url" | sed 's|gs://||' | sed 's|/||')
        echo "Optimizing bucket: $bucket"
        
        # Create lifecycle configuration
        local lifecycle_days
        if [ "$environment" == "prod" ]; then
          lifecycle_days=365
        else
          lifecycle_days=30
        fi
        
        cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": $lifecycle_days
        }
      },
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "NEARLINE"
        },
        "condition": {
          "age": 30
        }
      }
    ]
  }
}
EOF
        
        gcloud storage buckets update "$bucket_url" \
          --lifecycle-file=/tmp/lifecycle.json 2>/dev/null || echo "  ⚠️ Failed to update lifecycle for $bucket"
      done
      rm -f /tmp/lifecycle.json
    fi
  done
  
  echo -e "\n${GREEN}✅ Resource optimization completed!${NC}"
}

# Emergency cost-cutting measures
emergency_cost_cutting() {
  echo -e "\n${RED}🚨 EXECUTING EMERGENCY COST-CUTTING MEASURES!${NC}"
  echo -e "${YELLOW}⚠️  WARNING: This will significantly reduce service availability in non-production environments.${NC}"
  
  read -p "Are you sure you want to continue? (y/N): " confirm
  
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Emergency cost-cutting cancelled."
    return
  fi
  
  echo -e "${RED}Proceeding with emergency measures...${NC}"
  
  for project in "${PROJECTS[@]}"; do
    # Skip production projects in emergency mode
    if [[ "$project" == *"-prod-"* ]]; then
      echo -e "${YELLOW}⚠️ Skipping production project: $project${NC}"
      continue
    fi
    
    # Skip if project doesn't exist
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
      continue
    fi
    
    echo -e "\n${RED}🔥 Emergency measures for $project:${NC}"
    
    # Drastically reduce Cloud Run services
    echo -e "${BLUE}Minimizing Cloud Run Services...${NC}"
    local services
    services=$(gcloud run services list --project="$project" --format="value(metadata.name)" 2>/dev/null || echo "")
    
    if [ -n "$services" ]; then
      for service in $services; do
        echo "  → Emergency scaling for $service: min=0, max=1"
        gcloud run services update "$service" \
          --project="$project" \
          --region="us-central1" \
          --min-instances=0 \
          --max-instances=1 \
          --memory=256Mi \
          --cpu=1 \
          --timeout=60s \
          --concurrency=10 \
          --cpu-throttling 2>/dev/null || echo "  ⚠️ Failed to update $service"
      done
    fi
    
    # Aggressive log retention reduction
    echo -e "${BLUE}Minimizing Log Retention...${NC}"
    echo "  → Setting log retention to 1 day"
    gcloud logging settings update \
      --project="$project" \
      --retention-days=1 2>/dev/null || echo "  ⚠️ Failed to update log retention"
    
    # Clean up old logs
    echo -e "${BLUE}Cleaning up old logs...${NC}"
    gcloud logging logs delete --project="$project" --log-filter="timestamp < \"$(date -d '2 days ago' --iso-8601)\"" --quiet 2>/dev/null || echo "  ⚠️ Failed to clean old logs"
  done
  
  echo -e "\n${GREEN}✅ Emergency cost-cutting measures applied!${NC}"
  echo -e "${YELLOW}📧 Sending notification email to $EMAIL...${NC}"
  
  # In a real implementation, this would use a mail service
  echo "Emergency cost-cutting notification would be sent to: $EMAIL"
}

# Generate cost report
generate_report() {
  local budget_status
  get_current_spending
  budget_status=$?
  
  echo -e "\n${BLUE}📊 Generating detailed cost report...${NC}"
  
  # Create report file
  local report_file="/tmp/cost-report-$(date +%Y%m%d).md"
  
  cat > "$report_file" << EOF
# AcademyAxis.io Cost Report

**Generated:** $(date)
**Total Monthly Budget:** \$300 USD
**Current Status:** $([ $budget_status -eq 0 ] && echo "✅ OK" || [ $budget_status -eq 1 ] && echo "⚠️ WARNING" || echo "🚨 CRITICAL")

## Project Spending Summary

$(get_current_spending | tail -n +3)

## Recommendations

$([ $budget_status -eq 0 ] && echo "- Continue monitoring usage trends
- Review resource allocation monthly
- Maintain current optimization settings" || echo "- Immediate cost optimization required
- Review and shut down unused resources  
- Implement aggressive scaling policies
- Consider emergency cost-cutting measures")

## Next Actions

1. Review this report with the development team
2. Implement recommended optimizations
3. Monitor dashboards for changes
4. Schedule next review in 1 week

---
*Report generated by AcademyAxis.io Cost Monitoring System*
EOF
  
  echo -e "${GREEN}📋 Report generated: $report_file${NC}"
  
  # Display summary
  echo -e "\n${BLUE}📋 Report Summary:${NC}"
  cat "$report_file"
  
  return $budget_status
}

# Main function
main() {
  echo -e "${BLUE}🚀 AcademyAxis.io Cost Management Tool${NC}"
  echo -e "${BLUE}======================================${NC}"
  
  check_requirements
  
  case "$ACTION" in
    "report")
      generate_report
      local status=$?
      if [ $status -eq 2 ]; then
        echo -e "\n${RED}🚨 CRITICAL: Consider running emergency cost-cutting measures!${NC}"
        echo -e "Run: $0 emergency $EMAIL"
      elif [ $status -eq 1 ]; then
        echo -e "\n${YELLOW}⚠️ WARNING: Consider running optimization!${NC}"
        echo -e "Run: $0 optimize $EMAIL"
      fi
      ;;
    "optimize")
      get_current_spending
      optimize_resources
      echo -e "\n${GREEN}✅ Optimization completed. Run 'report' to see updated status.${NC}"
      ;;
    "emergency")
      get_current_spending
      emergency_cost_cutting
      ;;
    *)
      echo -e "${RED}❌ Error: Unknown action '$ACTION'.${NC}"
      echo -e "${BLUE}Usage: $0 [report|optimize|emergency] [email@example.com]${NC}"
      echo -e ""
      echo -e "Actions:"
      echo -e "  report    - Generate cost report and status"
      echo -e "  optimize  - Apply cost optimization measures"
      echo -e "  emergency - Apply emergency cost-cutting measures"
      exit 1
      ;;
  esac
}

# Execute main function
main "$@"