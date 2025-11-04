#!/bin/bash
set -euo pipefail

show_help() {
    cat << 'EOF'
AWS Helper - AWS operations and automation

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    ec2 list                List EC2 instances
    ec2 start <id>          Start EC2 instance
    ec2 stop <id>           Stop EC2 instance
    s3 sync <local> <s3>    Sync local directory to S3
    s3 backup <path>        Backup directory to S3 with timestamp
    logs <group> [stream]   Tail CloudWatch logs
    deploy <service>        Deploy service using CodeDeploy
    cost                    Show current month costs
    
Options:
    --profile PROFILE       AWS profile to use
    --region REGION         AWS region (default: us-east-1)
    -v, --verbose          Verbose output

Examples:
    $0 ec2 list --region us-west-2
    $0 s3 backup ~/project --profile prod
    $0 logs /aws/lambda/my-function
EOF
}

AWS_PROFILE=""
AWS_REGION="us-east-1"
VERBOSE=false

check_aws_cli() {
    command -v aws >/dev/null || { echo "AWS CLI not installed"; exit 1; }
}

aws_cmd() {
    local cmd="aws"
    [[ -n "$AWS_PROFILE" ]] && cmd="$cmd --profile $AWS_PROFILE"
    [[ -n "$AWS_REGION" ]] && cmd="$cmd --region $AWS_REGION"
    eval "$cmd $*"
}

ec2_operations() {
    local action="$1"
    local instance_id="${2:-}"
    
    case "$action" in
        list)
            echo "EC2 Instances in $AWS_REGION:"
            aws_cmd ec2 describe-instances \
                --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' \
                --output table
            ;;
        start)
            [[ -z "$instance_id" ]] && { echo "Instance ID required"; exit 1; }
            echo "Starting instance $instance_id..."
            aws_cmd ec2 start-instances --instance-ids "$instance_id"
            echo "✓ Start command sent"
            ;;
        stop)
            [[ -z "$instance_id" ]] && { echo "Instance ID required"; exit 1; }
            echo "Stopping instance $instance_id..."
            aws_cmd ec2 stop-instances --instance-ids "$instance_id"
            echo "✓ Stop command sent"
            ;;
        *)
            echo "EC2 actions: list, start <id>, stop <id>"
            ;;
    esac
}

s3_operations() {
    local action="$1"
    local source="${2:-}"
    local destination="${3:-}"
    
    case "$action" in
        sync)
            [[ -z "$source" || -z "$destination" ]] && { echo "Source and destination required"; exit 1; }
            echo "Syncing $source to $destination..."
            aws_cmd s3 sync "$source" "$destination" --delete
            echo "✓ Sync completed"
            ;;
        backup)
            [[ -z "$source" ]] && { echo "Source path required"; exit 1; }
            [[ ! -d "$source" ]] && { echo "Source directory not found"; exit 1; }
            
            local bucket_name="backup-$(whoami)-$(date +%Y%m%d)"
            local timestamp=$(date +%Y%m%d-%H%M%S)
            local backup_path="s3://$bucket_name/$(basename "$source")-$timestamp/"
            
            echo "Creating backup: $backup_path"
            aws_cmd s3 sync "$source" "$backup_path"
            echo "✓ Backup completed: $backup_path"
            ;;
        *)
            echo "S3 actions: sync <local> <s3>, backup <path>"
            ;;
    esac
}

cloudwatch_logs() {
    local log_group="$1"
    local log_stream="${2:-}"
    
    [[ -z "$log_group" ]] && { echo "Log group required"; exit 1; }
    
    echo "Tailing logs from $log_group..."
    
    if [[ -n "$log_stream" ]]; then
        aws_cmd logs tail "$log_group" --log-stream-names "$log_stream" --follow
    else
        aws_cmd logs tail "$log_group" --follow
    fi
}

deploy_service() {
    local service="$1"
    [[ -z "$service" ]] && { echo "Service name required"; exit 1; }
    
    echo "Deploying service: $service"
    
    local deployment_id=$(aws_cmd deploy create-deployment \
        --application-name "$service" \
        --deployment-group-name "production" \
        --s3-location bucket="deployments-$service",key="latest.zip",bundleType=zip \
        --query 'deploymentId' --output text)
    
    echo "Deployment created: $deployment_id"
    echo "Monitoring deployment status..."
    
    while true; do
        local status=$(aws_cmd deploy get-deployment \
            --deployment-id "$deployment_id" \
            --query 'deploymentInfo.status' --output text)
        
        echo "Status: $status"
        
        case "$status" in
            Succeeded) echo "✓ Deployment successful"; break ;;
            Failed|Stopped) echo "✗ Deployment failed"; exit 1 ;;
            *) sleep 10 ;;
        esac
    done
}

show_costs() {
    echo "AWS Costs for current month:"
    
    local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
    local end_date=$(date +%Y-%m-%d)
    
    aws_cmd ce get-cost-and-usage \
        --time-period Start="$start_date",End="$end_date" \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --query 'ResultsByTime[0].Groups[].[Keys[0],Metrics.BlendedCost.Amount]' \
        --output table
}

COMMAND=""
SUBCOMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        ec2|s3|logs|deploy|cost)
            COMMAND="$1"
            shift
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
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

check_aws_cli

case "$COMMAND" in
    ec2) ec2_operations "$SUBCOMMAND" "${ARGS[@]}" ;;
    s3) s3_operations "$SUBCOMMAND" "${ARGS[@]}" ;;
    logs) cloudwatch_logs "$SUBCOMMAND" "${ARGS[0]:-}" ;;
    deploy) deploy_service "$SUBCOMMAND" ;;
    cost) show_costs ;;
    "") show_help ;;
    *) echo "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac