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

# Check requirements
check_requirements() {
  echo -e "${BLUE}Checking requirements...${NC}"
  
  if ! command_exists gcloud; then
    echo -e "${RED}Error: gcloud is not installed. Please install Google Cloud SDK.${NC}"
    exit 1
  fi
  
  if ! command_exists jq; then
    echo -e "${YELLOW}Warning: jq is not installed. Some features will be limited.${NC}"
  fi
  
  # Check if user is logged in
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" >/dev/null; then
    echo -e "${RED}Error: Not logged in to gcloud. Please run 'gcloud auth login'.${NC}"
    exit 1
  }

  echo -e "${GREEN}All requirements satisfied.${NC}"
}

# Get current spending for all projects
get_current_spending() {
  echo -e "${BLUE}Getting current spending information...${NC}"
  
  local total_cost=0
  
  echo -e "\n${YELLOW}Current Monthly Spending:${NC}"
  printf "%-25s %-15s %-15s\n" "PROJECT" "COST (USD)" "BUDGET (USD)"
  printf "%-25s %-15s %-15s\n" "-----------------------" "---------------" "---------------"
  
  for project in "${PROJECTS[@]}"; do
    # Skip if project doesn't exist
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
      continue
    fi
    
    # Get project number for billing API
    local project_number=$(gcloud projects describe "$project" --format="value(projectNumber)")
    
    # Get current spending (this is a placeholder - actual implementation would use billing API)
    # In real implementation, use Billing API to get accurate costs
    local cost=0
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
      *)
        budget=25
        ;;
    esac
    
    # Simulate cost with random value (for demo purposes)
    cost=$(echo "$budget * $RANDOM / 32767" | bc -l)
    cost=$(printf "%.2f" $cost)
    
    printf "%-25s \$%-14s \$%-14s" "$project" "$cost" "$budget"
    
    # Calculate percentage of budget
    local percent=$(echo "scale=1; $cost / $budget * 100" | bc -l)
    if (( $(echo "$percent > 90" | bc -l) )); then
      printf " ${RED}(%.1f%%)${NC}\n" "$percent"
    elif (( $(echo "$percent > 75" | bc -l) )); then
      printf " ${YELLOW}(%.1f%%)${NC}\n" "$percent"
    else
      printf " ${GREEN}(%.1f%%)${NC}\n" "$percent"
    fi
    
    total_cost=$(echo "$total_cost + $cost" | bc -l)
  done
  
  printf "%-25s \$%-14.2f \$%-14s\n" "TOTAL" "$total_cost" "300"
  
  # Calculate total percentage
  local total_percent=$(echo "scale=1; $total_cost / 300 * 100" | bc -l)
  if (( $(echo "$total_percent > 90" | bc -l) )); then
    echo -e "${RED}ALERT: Currently at $total_percent% of total budget!${NC}"
  elif (( $(echo "$total_percent > 75" | bc -l) )); then
    echo -e "${YELLOW}WARNING: Currently at $total_percent% of total budget.${NC}"
  else
    echo -e "${GREEN}Budget status OK: Currently at $total_percent% of total budget.${NC}"
  fi
}

# Get resource usage for optimizing
get_resource_usage() {
  echo -e "\n${BLUE}Getting resource usage information...${NC}"
  
  for project in "${PROJECTS[@]}"; do
    # Skip if project doesn't exist
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
      continue
    }
    
    echo -e "\n${YELLOW}Resource usage for $project:${NC}"
    
    # Cloud Run services
    echo -e "\n${BLUE}Cloud Run Services:${NC}"
    printf "%-25s %-15s %-15s %-15s\n" "SERVICE" "MIN INSTANCES" "MAX INSTANCES" "MEMORY"
    printf "%-25s %-15s %-15s %-15s\n" "-----------------------" "---------------" "---------------" "---------------"
    
    # Get list of Cloud Run services
    local services=$(gcloud run services list --project="$project" --format="value(name)")
    if [ -z "$services" ]; then
      echo "No Cloud Run services found."
    else
      for service in $services; do
        local min_instances=$(gcloud run services describe "$service" --project="$project" --format="value(spec.template.metadata.annotations['autoscaling.knative.dev/minScale'])" 2>/dev/null || echo "0")
        local max_instances=$(gcloud run services describe "$service" --project="$project" --format="value(spec.template.metadata.annotations['autoscaling.knative.dev/maxScale'])" 2>/dev/null || echo "N/A")
        local memory=$(gcloud run services describe "$service" --project="$project" --format="value(spec.template.spec.containers[0].resources.limits.memory)" 2>/dev/null || echo "N/A")
        
        printf "%-25s %-15s %-15s %-15s\n" "$service" "$min_instances" "$max_instances" "$memory"
      done
    fi
    
    # Storage buckets
    echo -e "\n${BLUE}Storage Buckets:${NC}"
    printf "%-30s %-15s %-20s\n" "BUCKET" "SIZE (bytes)" "STORAGE CLASS"
    printf "%-30s %-15s %-20s\n" "------------------------------" "---------------" "--------------------"
    
    # Get list of storage buckets
    local buckets=$(gcloud storage ls --project="$project" 2>/dev/null | grep "gs://" || echo "")
    if [ -z "$buckets" ]; then
      echo "No storage buckets found."
    else
      for bucket in $buckets; do
        # Remove gs:// prefix
        bucket=${bucket#gs://}
        local size=$(gcloud storage du -s "gs://$bucket" 2>/dev/null | awk '{print $1}')
        [ -z "$size" ] && size="N/A"
        local storage_class=$(gcloud storage buckets describe "gs://$bucket" --format="value(storageClass)" 2>/dev/null || echo "N/A")
        
        printf "%-30s %-15s %-20s\n" "$bucket" "$size" "$storage_class"
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
      continue
    }
    
    echo -e "\n${YELLOW}Optimizing resources for $project:${NC}"
    
    # Determine environment based on project name
    local environment="dev"
    if [[ "$project" == *"-prod-"* ]]; then
      environment="prod"
    elif [[ "$project" == *"-uat-"* ]]; then
      environment="uat"
    fi
    
    # Cloud Run services
    echo -e "\n${BLUE}Optimizing Cloud Run Services:${NC}"
    
    # Get list of Cloud Run services
    local services=$(gcloud run services list --project="$project" --format="value(name)")
    if [ -z "$services" ]; then
      echo "No Cloud Run services found."
    else
      for service in $services; do
        if [ "$environment" == "prod" ]; then
          # Production optimization
          echo "Setting $service to min=1, max=100 for production..."
          gcloud run services update "$service" \
            --project="$project" \
            --min-instances=1 \
            --max-instances=100 \
            --no-cpu-throttling
        else
          # Dev/UAT optimization
          echo "Setting $service to min=0, max=10 for $environment..."
          gcloud run services update "$service" \
            --project="$project" \
            --min-instances=0 \
            --max-instances=10
        fi
      done
    fi
    
    # Log retention optimization
    echo -e "\n${BLUE}Optimizing Log Retention:${NC}"
    if [ "$environment" == "prod" ]; then
      echo "Setting log retention to 30 days for production..."
      gcloud logging settings update --project="$project" --retention-days=30
    else
      echo "Setting log retention to 7 days for $environment..."
      gcloud logging settings update --project="$project" --retention-days=7
    fi
    
    # Storage bucket optimization
    echo -e "\n${BLUE}Optimizing Storage Buckets:${NC}"
    local buckets=$(gcloud storage ls --project="$project" 2>/dev/null | grep "gs://" || echo "")
    if [ -z "$buckets" ]; then
      echo "No storage buckets found."
    else
      for bucket in $buckets; do
        # Remove gs:// prefix
        bucket=${bucket#gs://}
        
        echo "Setting lifecycle rules for bucket $bucket..."
        # Create a temporary file with lifecycle rules
        cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": $([[ "$environment" == "prod" ]] && echo "365" || echo "30")
        }
      }
    ]
  }
}
EOF
        # Apply lifecycle rules
        gcloud storage buckets update "gs://$bucket" --lifecycle-file=/tmp/lifecycle.json
        rm /tmp/lifecycle.json
      done
    fi
  done
  
  echo -e "\n${GREEN}Resources optimized successfully!${NC}"
}

# Emergency cost-cutting measures
emergency_cost_cutting() {
  echo -e "\n${RED}EXECUTING EMERGENCY COST-CUTTING MEASURES!${NC}"
  echo -e "${YELLOW}WARNING: This will reduce service availability in non-production environments.${NC}"
  read -p "Are you sure you want to continue? (y/N): " confirm
  
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Emergency cost-cutting cancelled."
    return
  fi
  
  for project in "${PROJECTS[@]}"; do
    # Skip production projects
    if [[ "$project" == *"-prod-"* ]]; then
      echo -e "${YELLOW}Skipping production project: $project${NC}"
      continue
    fi
    
    # Skip if project doesn't exist
    if ! gcloud projects describe "$project" >/dev/null 2>&1; then
      continue
    }
    
    echo -e "\n${RED}Emergency measures for $project:${NC}"
    
    # Cloud Run services
    echo -e "\n${BLUE}Reducing Cloud Run Services:${NC}"
    
    # Get list of Cloud Run services
    local services=$(gcloud run services list --project="$project" --format="value(name)")
    if [ -z "$services" ]; then
      echo "No Cloud Run services found."
    else
      for service in $services; do
        echo "Setting $service to min=0, max=1 and no traffic..."
        gcloud run services update "$service" \
          --project="$project" \
          --min-instances=0 \
          --max-instances=1
      done
    fi
    
    # Log retention reduction
    echo -e "\n${BLUE}Reducing Log Retention:${NC}"
    echo "Setting log retention to 1 day..."
    gcloud logging settings update --project="$project" --retention-days=1
  done
  
  # Send notification email
  echo -e "\n${BLUE}Sending notification email to $EMAIL...${NC}"
  
  # Placeholder for sending email
  echo "Email notification would be sent to $EMAIL about emergency cost-cutting measures."
  
  
  echo -e "\n${GREEN}Emergency cost-cutting measures applied!${NC}"
}

# Function to send a report email
send_report_email() {
  echo -e "\n${BLUE}Sending cost report to $EMAIL...${NC}"
  
  # In a real implementation, this would use a mail client to send the report
  # Here it's just a placeholder
  echo "Email would be sent to $EMAIL with cost report information."
}

# Main function
main() {
  check_requirements
  
  case "$ACTION" in
    "report")
      get_current_spending
      get_resource_usage
      send_report_email
      ;;
    "optimize")
      get_current_spending
      optimize_resources
      ;;
    "emergency")
      get_current_spending
      emergency_cost_cutting
      ;;
    *)
      echo -e "${RED}Error: Unknown action '$ACTION'.${NC}"
      echo "Usage: $0 [report|optimize|emergency] [email@example.com]"
      exit 1
      ;;
  esac
}

# Execute main function
main