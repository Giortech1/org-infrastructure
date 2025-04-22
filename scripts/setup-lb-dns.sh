#!/bin/bash
# File: scripts/setup-lb-dns.sh

set -e  # Exit on any error

# Default values
PROJECT_ID=${1:-"giortech-prod-project"}
APP_NAME=${2:-"giortech"}
ENVIRONMENT=${3:-"prod"}
REGION=${4:-"us-central1"}
DOMAIN="academyaxis.io"
SERVICE_NAME="${APP_NAME}-${ENVIRONMENT}"

echo "Setting up load balancer and DNS for ${APP_NAME} (${ENVIRONMENT}) in ${PROJECT_ID}..."

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable compute.googleapis.com \
    dns.googleapis.com \
    certificatemanager.googleapis.com \
    --project=${PROJECT_ID}

# Get service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --project=${PROJECT_ID} \
    --region=${REGION} \
    --format="get(status.url)")

echo "Found Cloud Run service at: ${SERVICE_URL}"

# Create global IP address
echo "Creating global IP address..."
gcloud compute addresses create ${SERVICE_NAME}-ip \
    --global \
    --project=${PROJECT_ID}

IP_ADDRESS=$(gcloud compute addresses describe ${SERVICE_NAME}-ip \
    --global \
    --format="get(address)" \
    --project=${PROJECT_ID})

echo "Reserved IP address: ${IP_ADDRESS}"

# Create serverless NEG
echo "Creating serverless NEG..."
gcloud compute network-endpoint-groups create ${SERVICE_NAME}-neg \
    --region=${REGION} \
    --network-endpoint-type=serverless \
    --cloud-run-service=${SERVICE_NAME} \
    --project=${PROJECT_ID}

# Create backend service
echo "Creating backend service..."
gcloud compute backend-services create ${SERVICE_NAME}-backend \
    --global \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --project=${PROJECT_ID}

# Add NEG to backend service
echo "Adding NEG to backend service..."
gcloud compute backend-services add-backend ${SERVICE_NAME}-backend \
    --global \
    --network-endpoint-group=${SERVICE_NAME}-neg \
    --network-endpoint-group-region=${REGION} \
    --project=${PROJECT_ID}

# Enable CDN for production
if [ "$ENVIRONMENT" = "prod" ]; then
    echo "Enabling Cloud CDN..."
    gcloud compute backend-services update ${SERVICE_NAME}-backend \
        --enable-cdn \
        --cache-mode=CACHE_ALL_STATIC \
        --global \
        --project=${PROJECT_ID}
fi

# Create URL map
echo "Creating URL map..."
gcloud compute url-maps create ${SERVICE_NAME}-urlmap \
    --default-service=${SERVICE_NAME}-backend \
    --project=${PROJECT_ID}

# Set domain name based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    FULL_DOMAIN="${APP_NAME}.${DOMAIN}"
else
    FULL_DOMAIN="${ENVIRONMENT}.${APP_NAME}.${DOMAIN}"
fi

# Handle SSL certificates
if [ "$ENVIRONMENT" = "prod" ]; then
    # Create certificate
    echo "Creating managed certificate for ${FULL_DOMAIN}..."
    gcloud certificate-manager certificates create ${SERVICE_NAME}-cert \
        --domains=${FULL_DOMAIN},www.${FULL_DOMAIN} \
        --project=${PROJECT_ID}
    
    # Create certificate map
    echo "Creating certificate map..."
    gcloud certificate-manager maps create ${SERVICE_NAME}-cert-map \
        --project=${PROJECT_ID}
    
    # Create certificate map entry
    echo "Creating certificate map entry..."
    gcloud certificate-manager maps entries create ${SERVICE_NAME}-map-entry \
        --map=${SERVICE_NAME}-cert-map \
        --certificates=${SERVICE_NAME}-cert \
        --hostname=${FULL_DOMAIN} \
        --project=${PROJECT_ID}
    
    # Create HTTPS target proxy with certificate map
    echo "Creating HTTPS target proxy with certificate map..."
    gcloud compute target-https-proxies create ${SERVICE_NAME}-https-proxy \
        --url-map=${SERVICE_NAME}-urlmap \
        --certificate-map=${SERVICE_NAME}-cert-map \
        --project=${PROJECT_ID}
else
    # Create self-signed certificate for non-prod
    echo "Creating self-signed certificate for ${FULL_DOMAIN}..."
    gcloud compute ssl-certificates create ${SERVICE_NAME}-cert \
        --global \
        --project=${PROJECT_ID}
    
    # Create HTTPS target proxy with self-signed certificate
    echo "Creating HTTPS target proxy with self-signed certificate..."
    gcloud compute target-https-proxies create ${SERVICE_NAME}-https-proxy \
        --url-map=${SERVICE_NAME}-urlmap \
        --ssl-certificates=${SERVICE_NAME}-cert \
        --project=${PROJECT_ID}
fi

# Create forwarding rule
echo "Creating forwarding rule..."
gcloud compute forwarding-rules create ${SERVICE_NAME}-https-rule \
    --address=${IP_ADDRESS} \
    --global \
    --target-https-proxy=${SERVICE_NAME}-https-proxy \
    --ports=443 \
    --project=${PROJECT_ID} \
    --load-balancing-scheme=EXTERNAL_MANAGED

# Setup DNS zone
echo "Setting up DNS zone..."
if ! gcloud dns managed-zones describe ${APP_NAME}-zone --project=${PROJECT_ID} &>/dev/null; then
    gcloud dns managed-zones create ${APP_NAME}-zone \
        --dns-name=${APP_NAME}.${DOMAIN}. \
        --description="DNS zone for ${APP_NAME}.${DOMAIN}" \
        --project=${PROJECT_ID}
    
    echo "Created DNS zone: ${APP_NAME}-zone"
else
    echo "DNS zone ${APP_NAME}-zone already exists"
fi

# Add/update DNS A record
echo "Updating DNS A record for ${FULL_DOMAIN}..."
gcloud dns record-sets transaction start --zone=${APP_NAME}-zone --project=${PROJECT_ID}

# Clean up any existing record first
existing_record=$(gcloud dns record-sets list \
    --zone=${APP_NAME}-zone \
    --name=${FULL_DOMAIN}. \
    --type=A \
    --project=${PROJECT_ID} \
    --format="get(name)" 2>/dev/null)

if [[ ! -z "$existing_record" ]]; then
    existing_ip=$(gcloud dns record-sets list \
        --zone=${APP_NAME}-zone \
        --name=${FULL_DOMAIN}. \
        --type=A \
        --project=${PROJECT_ID} \
        --format="get(rrdatas[0])")
    
    gcloud dns record-sets transaction remove \
        --zone=${APP_NAME}-zone \
        --name=${FULL_DOMAIN}. \
        --type=A \
        --ttl=300 \
        --rrdatas=${existing_ip} \
        --project=${PROJECT_ID}
fi

# Add the new record
gcloud dns record-sets transaction add \
    --zone=${APP_NAME}-zone \
    --name=${FULL_DOMAIN}. \
    --type=A \
    --ttl=300 \
    --rrdatas=${IP_ADDRESS} \
    --project=${PROJECT_ID}

gcloud dns record-sets transaction execute \
    --zone=${APP_NAME}-zone \
    --project=${PROJECT_ID}

# Add www CNAME for production
if [ "$ENVIRONMENT" = "prod" ] && [ "$APP_NAME" = "giortech" ]; then
    echo "Adding www CNAME for giortech..."
    existing_www_record=$(gcloud dns record-sets list \
        --zone=${APP_NAME}-zone \
        --name=www.${FULL_DOMAIN}. \
        --type=CNAME \
        --project=${PROJECT_ID} \
        --format="get(name)" 2>/dev/null)
    
    if [[ -z "$existing_www_record" ]]; then
        gcloud dns record-sets create www.${FULL_DOMAIN}. \
            --type=CNAME \
            --ttl=300 \
            --zone=${APP_NAME}-zone \
            --rrdatas=${FULL_DOMAIN}. \
            --project=${PROJECT_ID}
    fi
fi

# Get name servers for the DNS zone
NAME_SERVERS=$(gcloud dns managed-zones describe ${APP_NAME}-zone \
    --format="get(nameServers)" \
    --project=${PROJECT_ID})

echo "=================================================================="
echo "Setup complete for ${APP_NAME} (${ENVIRONMENT})!"
echo "IP Address: ${IP_ADDRESS}"
echo "Domain: ${FULL_DOMAIN}"
echo ""
echo "DNS Configuration:"
echo "Name Servers: ${NAME_SERVERS}"
echo ""
echo "IMPORTANT: You need to configure these name servers in your domain registrar"
echo "for the ${APP_NAME}.${DOMAIN} domain."
echo "=================================================================="