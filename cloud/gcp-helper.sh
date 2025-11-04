#!/bin/bash
set -euo pipefail

show_help() {
    cat << 'EOF'
GCP Helper - Google Cloud Platform operations

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    compute list            List Compute Engine instances
    compute start <name>    Start VM instance
    compute stop <name>     Stop VM instance
    storage sync <local> <bucket>  Sync to Cloud Storage
    storage backup <path>   Backup with timestamp
    logs <resource>         Stream logs
    deploy <service>        Deploy to Cloud Run
    billing                 Show current billing
    
Options:
    --project PROJECT       GCP project ID
    --zone ZONE            GCP zone (default: us-central1-a)
    -v, --verbose          Verbose output

Examples:
    $0 compute list --zone us-west1-b
    $0 storage backup ~/app --project my-project
    $0 deploy my-service
EOF
}

GCP_PROJECT=""
GCP_ZONE="us-central1-a"
VERBOSE=false

check_gcloud() {
    command -v gcloud >/dev/null || { echo "gcloud CLI not installed"; exit 1; }
}

gcloud_cmd() {
    local cmd="gcloud"
    [[ -n "$GCP_PROJECT" ]] && cmd="$cmd --project=$GCP_PROJECT"
    eval "$cmd $*"
}

compute_operations() {
    local action="$1"
    local instance_name="${2:-}"
    
    case "$action" in
        list)
            echo "Compute Engine instances in $GCP_ZONE:"
            gcloud_cmd compute instances list --zones="$GCP_ZONE" \
                --format="table(name,status,machineType.basename(),zone.basename())"
            ;;
        start)
            [[ -z "$instance_name" ]] && { echo "Instance name required"; exit 1; }
            echo "Starting instance $instance_name..."
            gcloud_cmd compute instances start "$instance_name" --zone="$GCP_ZONE"
            echo "✓ Instance started"
            ;;
        stop)
            [[ -z "$instance_name" ]] && { echo "Instance name required"; exit 1; }
            echo "Stopping instance $instance_name..."
            gcloud_cmd compute instances stop "$instance_name" --zone="$GCP_ZONE"
            echo "✓ Instance stopped"
            ;;
        *)
            echo "Compute actions: list, start <name>, stop <name>"
            ;;
    esac
}

storage_operations() {
    local action="$1"
    local source="${2:-}"
    local destination="${3:-}"
    
    case "$action" in
        sync)
            [[ -z "$source" || -z "$destination" ]] && { echo "Source and destination required"; exit 1; }
            echo "Syncing $source to gs://$destination..."
            gsutil -m rsync -r -d "$source" "gs://$destination"
            echo "✓ Sync completed"
            ;;
        backup)
            [[ -z "$source" ]] && { echo "Source path required"; exit 1; }
            [[ ! -d "$source" ]] && { echo "Source directory not found"; exit 1; }
            
            local bucket_name="backup-$(whoami)-$(date +%Y%m%d)"
            local timestamp=$(date +%Y%m%d-%H%M%S)
            local backup_path="gs://$bucket_name/$(basename "$source")-$timestamp/"
            
            echo "Creating backup: $backup_path"
            gsutil -m cp -r "$source" "$backup_path"
            echo "✓ Backup completed: $backup_path"
            ;;
        *)
            echo "Storage actions: sync <local> <bucket>, backup <path>"
            ;;
    esac
}

stream_logs() {
    local resource="$1"
    [[ -z "$resource" ]] && { echo "Resource name required"; exit 1; }
    
    echo "Streaming logs for $resource..."
    gcloud_cmd logging tail "$resource" --format="value(timestamp,severity,textPayload)"
}

deploy_cloudrun() {
    local service="$1"
    [[ -z "$service" ]] && { echo "Service name required"; exit 1; }
    
    echo "Deploying to Cloud Run: $service"
    
    if [[ -f "Dockerfile" ]]; then
        echo "Building container image..."
        gcloud_cmd builds submit --tag "gcr.io/$GCP_PROJECT/$service"
        
        echo "Deploying service..."
        gcloud_cmd run deploy "$service" \
            --image "gcr.io/$GCP_PROJECT/$service" \
            --platform managed \
            --region us-central1 \
            --allow-unauthenticated
        
        echo "✓ Deployment completed"
    else
        echo "No Dockerfile found. Creating basic Node.js Dockerfile..."
        cat > Dockerfile << 'EOF'
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 8080
CMD ["npm", "start"]
EOF
        echo "Dockerfile created. Run deploy again."
    fi
}

show_billing() {
    echo "GCP Billing information:"
    
    gcloud_cmd billing accounts list --format="table(name,displayName,open)"
    
    echo -e "\nCurrent month usage (if billing export is configured):"
    gcloud_cmd logging read 'resource.type="billing_account"' \
        --limit=10 --format="table(timestamp,jsonPayload.cost)" 2>/dev/null || \
        echo "Billing export not configured or no recent data"
}

COMMAND=""
SUBCOMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        compute|storage|logs|deploy|billing)
            COMMAND="$1"
            shift
            ;;
        --project)
            GCP_PROJECT="$2"
            shift 2
            ;;
        --zone)
            GCP_ZONE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$SUBCOMMAND" ]]; then
                SUBCOMMAND="$1"
            else
                ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

check_gcloud

[[ -z "$GCP_PROJECT" ]] && GCP_PROJECT=$(gcloud config get-value project 2>/dev/null)

case "$COMMAND" in
    compute) compute_operations "$SUBCOMMAND" "${ARGS[@]}" ;;
    storage) storage_operations "$SUBCOMMAND" "${ARGS[@]}" ;;
    logs) stream_logs "$SUBCOMMAND" ;;
    deploy) deploy_cloudrun "$SUBCOMMAND" ;;
    billing) show_billing ;;
    "") show_help ;;
    *) echo "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac