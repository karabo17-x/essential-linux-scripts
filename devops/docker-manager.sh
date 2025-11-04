#!/bin/bash
set -euo pipefail

show_help() {
    cat << 'EOF'
Docker Manager - Container lifecycle and automation

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    build <name> [path]     Build image from Dockerfile
    run <image> [options]   Run container with smart defaults
    compose <action>        Docker Compose operations (up/down/logs)
    clean                   Clean unused containers, images, volumes
    logs <container>        Stream container logs
    exec <container> [cmd]  Execute command in container
    health <container>      Check container health
    backup <container>      Backup container volumes
    
Options:
    -p, --port PORT        Expose port (format: host:container)
    -v, --volume VOL       Mount volume (format: host:container)
    -e, --env KEY=VALUE    Set environment variable
    -d, --detach          Run in background
    --no-cache            Build without cache

Examples:
    $0 build myapp .
    $0 run nginx -p 8080:80 -d
    $0 compose up -d
    $0 clean --all
EOF
}

PORTS=()
VOLUMES=()
ENV_VARS=()
DETACH=false
NO_CACHE=false

build_image() {
    local name="$1"
    local path="${2:-.}"
    
    [[ ! -f "$path/Dockerfile" ]] && { echo "No Dockerfile found in $path"; exit 1; }
    
    echo "Building image: $name"
    
    local build_cmd="docker build -t $name"
    [[ "$NO_CACHE" == true ]] && build_cmd="$build_cmd --no-cache"
    build_cmd="$build_cmd $path"
    
    eval "$build_cmd"
    echo "✓ Image built: $name"
}

run_container() {
    local image="$1"
    shift
    
    local run_cmd="docker run"
    [[ "$DETACH" == true ]] && run_cmd="$run_cmd -d"
    
    for port in "${PORTS[@]}"; do
        run_cmd="$run_cmd -p $port"
    done
    
    for volume in "${VOLUMES[@]}"; do
        run_cmd="$run_cmd -v $volume"
    done
    
    for env in "${ENV_VARS[@]}"; do
        run_cmd="$run_cmd -e $env"
    done
    
    run_cmd="$run_cmd --name $(echo "$image" | tr '/' '-')-$(date +%s)"
    run_cmd="$run_cmd $image $*"
    
    echo "Running: $run_cmd"
    eval "$run_cmd"
}

compose_operations() {
    local action="$1"
    
    [[ ! -f "docker-compose.yml" ]] && { echo "No docker-compose.yml found"; exit 1; }
    
    case "$action" in
        up)
            docker-compose up -d
            echo "✓ Services started"
            docker-compose ps
            ;;
        down)
            docker-compose down
            echo "✓ Services stopped"
            ;;
        logs)
            docker-compose logs -f
            ;;
        restart)
            docker-compose restart
            echo "✓ Services restarted"
            ;;
        ps)
            docker-compose ps
            ;;
        *)
            echo "Compose actions: up, down, logs, restart, ps"
            ;;
    esac
}

clean_docker() {
    local clean_all="${1:-false}"
    
    echo "Cleaning Docker resources..."
    
    echo "Removing stopped containers..."
    docker container prune -f
    
    echo "Removing unused images..."
    docker image prune -f
    
    if [[ "$clean_all" == "--all" ]]; then
        echo "Removing all unused images..."
        docker image prune -a -f
        
        echo "Removing unused volumes..."
        docker volume prune -f
        
        echo "Removing unused networks..."
        docker network prune -f
    fi
    
    echo "✓ Cleanup completed"
    docker system df
}

stream_logs() {
    local container="$1"
    [[ -z "$container" ]] && { echo "Container name required"; exit 1; }
    
    echo "Streaming logs from $container..."
    docker logs -f "$container"
}

exec_command() {
    local container="$1"
    local cmd="${2:-/bin/bash}"
    
    [[ -z "$container" ]] && { echo "Container name required"; exit 1; }
    
    echo "Executing in $container: $cmd"
    docker exec -it "$container" $cmd
}

check_health() {
    local container="$1"
    [[ -z "$container" ]] && { echo "Container name required"; exit 1; }
    
    echo "Health check for $container:"
    
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
    
    case "$status" in
        healthy) echo "✓ Container is healthy" ;;
        unhealthy) echo "✗ Container is unhealthy" ;;
        starting) echo "⏳ Health check starting..." ;;
        no-healthcheck) echo "ℹ No health check configured" ;;
        *) echo "Unknown health status: $status" ;;
    esac
    
    echo -e "\nContainer stats:"
    docker stats "$container" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

backup_container() {
    local container="$1"
    [[ -z "$container" ]] && { echo "Container name required"; exit 1; }
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="${container}-backup-${timestamp}.tar"
    
    echo "Creating backup of $container volumes..."
    
    local volumes=$(docker inspect "$container" --format='{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}')
    
    if [[ -n "$volumes" ]]; then
        docker run --rm \
            --volumes-from "$container" \
            -v "$(pwd):/backup" \
            alpine tar czf "/backup/$backup_file" /data 2>/dev/null || \
            echo "Backup may be incomplete - check container volumes"
        
        echo "✓ Backup created: $backup_file"
    else
        echo "No volumes found to backup"
    fi
}

COMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        build|run|compose|clean|logs|exec|health|backup)
            COMMAND="$1"
            shift
            ;;
        -p|--port)
            PORTS+=("$2")
            shift 2
            ;;
        -v|--volume)
            VOLUMES+=("$2")
            shift 2
            ;;
        -e|--env)
            ENV_VARS+=("$2")
            shift 2
            ;;
        -d|--detach)
            DETACH=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
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

command -v docker >/dev/null || { echo "Docker not installed"; exit 1; }

case "$COMMAND" in
    build) build_image "${ARGS[@]}" ;;
    run) run_container "${ARGS[@]}" ;;
    compose) compose_operations "${ARGS[0]:-up}" ;;
    clean) clean_docker "${ARGS[0]:-}" ;;
    logs) stream_logs "${ARGS[0]}" ;;
    exec) exec_command "${ARGS[0]}" "${ARGS[1]:-}" ;;
    health) check_health "${ARGS[0]}" ;;
    backup) backup_container "${ARGS[0]}" ;;
    "") show_help ;;
    *) echo "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac