#!/bin/bash
set -euo pipefail

show_help() {
    cat << 'EOF'
Kubernetes Helper - K8s cluster management and automation

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    pods [namespace]        List pods with status
    deploy <file>           Deploy from YAML file
    scale <deployment> <replicas>  Scale deployment
    logs <pod> [container]  Stream pod logs
    exec <pod> [cmd]        Execute in pod
    port-forward <pod> <ports>  Forward ports
    rollout <deployment>    Rollout operations
    secrets <action>        Manage secrets
    health                  Cluster health check
    
Options:
    -n, --namespace NS     Kubernetes namespace
    -f, --follow          Follow logs
    -w, --watch           Watch resources
    --context CONTEXT     Kubectl context

Examples:
    $0 pods -n production
    $0 deploy app.yaml
    $0 scale myapp 3
    $0 logs myapp-pod -f
EOF
}

NAMESPACE=""
FOLLOW=false
WATCH=false
CONTEXT=""

check_kubectl() {
    command -v kubectl >/dev/null || { echo "kubectl not installed"; exit 1; }
}

kubectl_cmd() {
    local cmd="kubectl"
    [[ -n "$CONTEXT" ]] && cmd="$cmd --context=$CONTEXT"
    [[ -n "$NAMESPACE" ]] && cmd="$cmd -n $NAMESPACE"
    eval "$cmd $*"
}

list_pods() {
    local ns="${1:-}"
    [[ -n "$ns" ]] && NAMESPACE="$ns"
    
    echo "Pods in namespace: ${NAMESPACE:-default}"
    
    if [[ "$WATCH" == true ]]; then
        kubectl_cmd get pods -w
    else
        kubectl_cmd get pods -o wide
        echo -e "\nPod resource usage:"
        kubectl_cmd top pods 2>/dev/null || echo "Metrics server not available"
    fi
}

deploy_resource() {
    local file="$1"
    [[ -z "$file" ]] && { echo "YAML file required"; exit 1; }
    [[ ! -f "$file" ]] && { echo "File not found: $file"; exit 1; }
    
    echo "Deploying from $file..."
    kubectl_cmd apply -f "$file"
    
    echo "✓ Resources deployed"
    echo "Checking rollout status..."
    
    local deployments=$(kubectl_cmd get -f "$file" -o jsonpath='{.items[?(@.kind=="Deployment")].metadata.name}' 2>/dev/null || true)
    for deployment in $deployments; do
        kubectl_cmd rollout status deployment/"$deployment" --timeout=300s
    done
}

scale_deployment() {
    local deployment="$1"
    local replicas="$2"
    
    [[ -z "$deployment" || -z "$replicas" ]] && { echo "Deployment name and replica count required"; exit 1; }
    
    echo "Scaling $deployment to $replicas replicas..."
    kubectl_cmd scale deployment "$deployment" --replicas="$replicas"
    
    echo "Waiting for rollout..."
    kubectl_cmd rollout status deployment/"$deployment"
    echo "✓ Scaling completed"
}

stream_logs() {
    local pod="$1"
    local container="${2:-}"
    
    [[ -z "$pod" ]] && { echo "Pod name required"; exit 1; }
    
    local log_cmd="logs $pod"
    [[ -n "$container" ]] && log_cmd="$log_cmd -c $container"
    [[ "$FOLLOW" == true ]] && log_cmd="$log_cmd -f"
    
    echo "Streaming logs from $pod${container:+ ($container)}..."
    kubectl_cmd $log_cmd
}

exec_pod() {
    local pod="$1"
    local cmd="${2:-/bin/bash}"
    
    [[ -z "$pod" ]] && { echo "Pod name required"; exit 1; }
    
    echo "Executing in $pod: $cmd"
    kubectl_cmd exec -it "$pod" -- $cmd
}

port_forward() {
    local pod="$1"
    local ports="$2"
    
    [[ -z "$pod" || -z "$ports" ]] && { echo "Pod name and ports required (format: local:remote)"; exit 1; }
    
    echo "Port forwarding $ports to $pod..."
    kubectl_cmd port-forward "$pod" "$ports"
}

rollout_operations() {
    local deployment="$1"
    local action="${2:-status}"
    
    [[ -z "$deployment" ]] && { echo "Deployment name required"; exit 1; }
    
    case "$action" in
        status)
            kubectl_cmd rollout status deployment/"$deployment"
            ;;
        restart)
            kubectl_cmd rollout restart deployment/"$deployment"
            echo "✓ Rollout restarted"
            ;;
        undo)
            kubectl_cmd rollout undo deployment/"$deployment"
            echo "✓ Rollout undone"
            ;;
        history)
            kubectl_cmd rollout history deployment/"$deployment"
            ;;
        *)
            echo "Rollout actions: status, restart, undo, history"
            ;;
    esac
}

manage_secrets() {
    local action="$1"
    local name="${2:-}"
    
    case "$action" in
        list)
            kubectl_cmd get secrets
            ;;
        create)
            [[ -z "$name" ]] && { echo "Secret name required"; exit 1; }
            echo "Creating secret $name (enter key=value pairs, empty line to finish):"
            
            local secret_data=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                secret_data="$secret_data --from-literal=$line"
            done
            
            kubectl_cmd create secret generic "$name" $secret_data
            echo "✓ Secret created"
            ;;
        delete)
            [[ -z "$name" ]] && { echo "Secret name required"; exit 1; }
            kubectl_cmd delete secret "$name"
            echo "✓ Secret deleted"
            ;;
        *)
            echo "Secret actions: list, create <name>, delete <name>"
            ;;
    esac
}

cluster_health() {
    echo "=== Cluster Health Check ==="
    
    echo "Cluster info:"
    kubectl cluster-info
    
    echo -e "\nNode status:"
    kubectl get nodes -o wide
    
    echo -e "\nNamespaces:"
    kubectl get namespaces
    
    echo -e "\nSystem pods:"
    kubectl get pods -n kube-system --field-selector=status.phase!=Running 2>/dev/null || true
    
    echo -e "\nResource usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    
    echo -e "\nPersistent volumes:"
    kubectl get pv 2>/dev/null || echo "No PVs found"
    
    echo -e "\nEvents (last 10):"
    kubectl get events --sort-by='.lastTimestamp' | tail -10
}

COMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        pods|deploy|scale|logs|exec|port-forward|rollout|secrets|health)
            COMMAND="$1"
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -w|--watch)
            WATCH=true
            shift
            ;;
        --context)
            CONTEXT="$2"
            shift 2
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

check_kubectl

case "$COMMAND" in
    pods) list_pods "${ARGS[0]:-}" ;;
    deploy) deploy_resource "${ARGS[0]}" ;;
    scale) scale_deployment "${ARGS[0]}" "${ARGS[1]}" ;;
    logs) stream_logs "${ARGS[0]}" "${ARGS[1]:-}" ;;
    exec) exec_pod "${ARGS[0]}" "${ARGS[1]:-}" ;;
    port-forward) port_forward "${ARGS[0]}" "${ARGS[1]}" ;;
    rollout) rollout_operations "${ARGS[0]}" "${ARGS[1]:-}" ;;
    secrets) manage_secrets "${ARGS[0]:-list}" "${ARGS[1]:-}" ;;
    health) cluster_health ;;
    "") show_help ;;
    *) echo "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac