#!/bin/bash
set -euo pipefail

show_help() {
    cat << 'EOF'
Terraform Helper - Infrastructure as Code automation

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    init [backend]          Initialize Terraform with optional backend
    plan [target]           Create execution plan
    apply [target]          Apply changes
    destroy [target]        Destroy infrastructure
    validate                Validate configuration
    format                  Format Terraform files
    state <action>          State management operations
    workspace <action>      Workspace operations
    
Options:
    --auto-approve         Skip interactive approval
    --var-file FILE        Variable file to use
    --backend-config FILE  Backend configuration file
    -v, --verbose          Verbose output

Examples:
    $0 init s3
    $0 plan --var-file prod.tfvars
    $0 apply --auto-approve
    $0 workspace new staging
EOF
}

AUTO_APPROVE=false
VAR_FILE=""
BACKEND_CONFIG=""
VERBOSE=false

check_terraform() {
    command -v terraform >/dev/null || { echo "Terraform not installed"; exit 1; }
}

tf_cmd() {
    local cmd="terraform"
    [[ -n "$VAR_FILE" ]] && cmd="$cmd -var-file=$VAR_FILE"
    [[ "$VERBOSE" == true ]] && cmd="$cmd -verbose"
    eval "$cmd $*"
}

init_terraform() {
    local backend="${1:-}"
    
    echo "Initializing Terraform..."
    
    case "$backend" in
        s3)
            cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
EOF
            echo "S3 backend configuration created"
            ;;
        gcs)
            cat > backend.tf << 'EOF'
terraform {
  backend "gcs" {
    bucket = "terraform-state-bucket"
    prefix = "terraform/state"
  }
}
EOF
            echo "GCS backend configuration created"
            ;;
        azurerm)
            cat > backend.tf << 'EOF'
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-rg"
    storage_account_name = "terraformstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
EOF
            echo "Azure backend configuration created"
            ;;
    esac
    
    local init_cmd="terraform init"
    [[ -n "$BACKEND_CONFIG" ]] && init_cmd="$init_cmd -backend-config=$BACKEND_CONFIG"
    
    eval "$init_cmd"
    echo "✓ Terraform initialized"
}

plan_terraform() {
    local target="${1:-}"
    
    echo "Creating Terraform plan..."
    
    local plan_cmd="terraform plan"
    [[ -n "$target" ]] && plan_cmd="$plan_cmd -target=$target"
    [[ -n "$VAR_FILE" ]] && plan_cmd="$plan_cmd -var-file=$VAR_FILE"
    
    eval "$plan_cmd -out=tfplan"
    echo "✓ Plan created and saved to tfplan"
}

apply_terraform() {
    local target="${1:-}"
    
    if [[ -f "tfplan" ]]; then
        echo "Applying saved plan..."
        terraform apply tfplan
    else
        echo "Applying Terraform configuration..."
        
        local apply_cmd="terraform apply"
        [[ -n "$target" ]] && apply_cmd="$apply_cmd -target=$target"
        [[ -n "$VAR_FILE" ]] && apply_cmd="$apply_cmd -var-file=$VAR_FILE"
        [[ "$AUTO_APPROVE" == true ]] && apply_cmd="$apply_cmd -auto-approve"
        
        eval "$apply_cmd"
    fi
    
    echo "✓ Terraform apply completed"
}

destroy_terraform() {
    local target="${1:-}"
    
    echo "Destroying Terraform infrastructure..."
    
    if [[ "$AUTO_APPROVE" == false ]]; then
        read -p "Are you sure you want to destroy infrastructure? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Destroy cancelled"; exit 0; }
    fi
    
    local destroy_cmd="terraform destroy"
    [[ -n "$target" ]] && destroy_cmd="$destroy_cmd -target=$target"
    [[ -n "$VAR_FILE" ]] && destroy_cmd="$destroy_cmd -var-file=$VAR_FILE"
    [[ "$AUTO_APPROVE" == true ]] && destroy_cmd="$destroy_cmd -auto-approve"
    
    eval "$destroy_cmd"
    echo "✓ Infrastructure destroyed"
}

validate_terraform() {
    echo "Validating Terraform configuration..."
    terraform validate
    echo "✓ Configuration is valid"
}

format_terraform() {
    echo "Formatting Terraform files..."
    terraform fmt -recursive
    echo "✓ Files formatted"
}

manage_state() {
    local action="$1"
    local resource="${2:-}"
    
    case "$action" in
        list)
            terraform state list
            ;;
        show)
            [[ -z "$resource" ]] && { echo "Resource required for show"; exit 1; }
            terraform state show "$resource"
            ;;
        mv)
            local destination="${3:-}"
            [[ -z "$resource" || -z "$destination" ]] && { echo "Source and destination required"; exit 1; }
            terraform state mv "$resource" "$destination"
            echo "✓ State moved"
            ;;
        rm)
            [[ -z "$resource" ]] && { echo "Resource required for removal"; exit 1; }
            terraform state rm "$resource"
            echo "✓ Resource removed from state"
            ;;
        pull)
            terraform state pull > terraform.tfstate.backup
            echo "✓ State pulled and backed up"
            ;;
        *)
            echo "State actions: list, show <resource>, mv <src> <dst>, rm <resource>, pull"
            ;;
    esac
}

manage_workspace() {
    local action="$1"
    local name="${2:-}"
    
    case "$action" in
        list)
            terraform workspace list
            ;;
        new)
            [[ -z "$name" ]] && { echo "Workspace name required"; exit 1; }
            terraform workspace new "$name"
            echo "✓ Workspace '$name' created and selected"
            ;;
        select)
            [[ -z "$name" ]] && { echo "Workspace name required"; exit 1; }
            terraform workspace select "$name"
            echo "✓ Workspace '$name' selected"
            ;;
        delete)
            [[ -z "$name" ]] && { echo "Workspace name required"; exit 1; }
            terraform workspace delete "$name"
            echo "✓ Workspace '$name' deleted"
            ;;
        show)
            terraform workspace show
            ;;
        *)
            echo "Workspace actions: list, new <name>, select <name>, delete <name>, show"
            ;;
    esac
}

COMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        init|plan|apply|destroy|validate|format|state|workspace)
            COMMAND="$1"
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --var-file)
            VAR_FILE="$2"
            shift 2
            ;;
        --backend-config)
            BACKEND_CONFIG="$2"
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
            ARGS+=("$1")
            shift
            ;;
    esac
done

check_terraform

case "$COMMAND" in
    init) init_terraform "${ARGS[0]:-}" ;;
    plan) plan_terraform "${ARGS[0]:-}" ;;
    apply) apply_terraform "${ARGS[0]:-}" ;;
    destroy) destroy_terraform "${ARGS[0]:-}" ;;
    validate) validate_terraform ;;
    format) format_terraform ;;
    state) manage_state "${ARGS[0]:-list}" "${ARGS[1]:-}" "${ARGS[2]:-}" ;;
    workspace) manage_workspace "${ARGS[0]:-list}" "${ARGS[1]:-}" ;;
    "") show_help ;;
    *) echo "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac