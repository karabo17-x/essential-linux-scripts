#!/bin/bash

# Environment Manager - Manage development environments and dependencies
# Compatible with all Linux distributions

set -euo pipefail

show_help() {
    cat << EOF
Environment Manager - Manage development environments

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    check, c           Check installed development tools
    install, i         Install common development tools
    node, n            Manage Node.js versions
    python, py         Manage Python environments
    docker, d          Docker environment setup
    
Options:
    -v, --verbose      Show detailed output
    -h, --help         Show this help message

Examples:
    $0 check
    $0 install node
    $0 python create myproject
    $0 docker setup
EOF
}

VERBOSE=false

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "  $1"
    fi
}

check_tools() {
    echo "=== Development Tools Check ==="
    
    local tools=(
        "git:Git version control"
        "curl:HTTP client"
        "wget:File downloader"
        "node:Node.js runtime"
        "npm:Node package manager"
        "python3:Python 3"
        "pip3:Python package manager"
        "docker:Docker containers"
        "docker-compose:Docker Compose"
        "go:Go programming language"
        "rust:Rust programming language"
        "java:Java runtime"
        "gcc:GNU C Compiler"
        "make:Build automation"
        "vim:Text editor"
        "code:VS Code"
    )
    
    for tool_info in "${tools[@]}"; do
        local tool=$(echo "$tool_info" | cut -d: -f1)
        local description=$(echo "$tool_info" | cut -d: -f2)
        
        if command -v "$tool" &> /dev/null; then
            local version=""
            case "$tool" in
                git) version=$(git --version | awk '{print $3}') ;;
                node) version=$(node --version) ;;
                python3) version=$(python3 --version | awk '{print $2}') ;;
                docker) version=$(docker --version | awk '{print $3}' | sed 's/,//') ;;
                go) version=$(go version | awk '{print $3}') ;;
                *) version="installed" ;;
            esac
            echo "✓ $tool ($description) - $version"
        else
            echo "✗ $tool ($description) - not installed"
        fi
    done
}

install_tool() {
    local tool="$1"
    
    case "$tool" in
        node)
            install_node
            ;;
        python)
            install_python_tools
            ;;
        docker)
            install_docker
            ;;
        basic)
            install_basic_tools
            ;;
        *)
            echo "Unknown tool: $tool"
            echo "Available: node, python, docker, basic"
            exit 1
            ;;
    esac
}

install_basic_tools() {
    echo "Installing basic development tools..."
    
    # Detect package manager
    if command -v apt &> /dev/null; then
        log "Using apt package manager"
        sudo apt update
        sudo apt install -y git curl wget build-essential vim
    elif command -v yum &> /dev/null; then
        log "Using yum package manager"
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y git curl wget vim
    elif command -v dnf &> /dev/null; then
        log "Using dnf package manager"
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y git curl wget vim
    elif command -v pacman &> /dev/null; then
        log "Using pacman package manager"
        sudo pacman -S --noconfirm git curl wget base-devel vim
    elif command -v apk &> /dev/null; then
        log "Using apk package manager"
        sudo apk add git curl wget build-base vim
    else
        echo "No supported package manager found"
        exit 1
    fi
    
    echo "✓ Basic development tools installed"
}

install_node() {
    echo "Installing Node.js..."
    
    if command -v node &> /dev/null; then
        echo "Node.js already installed: $(node --version)"
        return
    fi
    
    # Try to install via package manager first
    if command -v apt &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo yum install -y nodejs npm
    elif command -v dnf &> /dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
        sudo dnf install -y nodejs npm
    else
        echo "Manual Node.js installation required for this system"
        echo "Visit: https://nodejs.org/en/download/"
        exit 1
    fi
    
    echo "✓ Node.js installed: $(node --version)"
}

install_python_tools() {
    echo "Installing Python development tools..."
    
    if command -v apt &> /dev/null; then
        sudo apt install -y python3 python3-pip python3-venv
    elif command -v yum &> /dev/null; then
        sudo yum install -y python3 python3-pip
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 python3-pip
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm python python-pip
    elif command -v apk &> /dev/null; then
        sudo apk add python3 py3-pip
    else
        echo "No supported package manager found"
        exit 1
    fi
    
    echo "✓ Python tools installed"
}

install_docker() {
    echo "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        echo "Docker already installed: $(docker --version)"
        return
    fi
    
    # Install Docker using official script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    echo "✓ Docker installed"
    echo "Note: Log out and back in to use Docker without sudo"
}

manage_node() {
    local action="$1"
    
    case "$action" in
        list)
            if command -v node &> /dev/null; then
                echo "Current Node.js version: $(node --version)"
                echo "NPM version: $(npm --version)"
            else
                echo "Node.js not installed"
            fi
            ;;
        update)
            if command -v npm &> /dev/null; then
                echo "Updating npm to latest version..."
                npm install -g npm@latest
                echo "✓ npm updated to: $(npm --version)"
            else
                echo "npm not available"
            fi
            ;;
        *)
            echo "Node actions: list, update"
            ;;
    esac
}

manage_python() {
    local action="$1"
    local project_name="${2:-}"
    
    case "$action" in
        list)
            if command -v python3 &> /dev/null; then
                echo "Python version: $(python3 --version)"
                echo "Pip version: $(pip3 --version 2>/dev/null || echo 'not available')"
            else
                echo "Python 3 not installed"
            fi
            ;;
        create)
            if [[ -z "$project_name" ]]; then
                echo "Project name required: $0 python create <project_name>"
                exit 1
            fi
            
            if command -v python3 &> /dev/null; then
                echo "Creating Python virtual environment: $project_name"
                python3 -m venv "$project_name"
                echo "✓ Virtual environment created"
                echo "Activate with: source $project_name/bin/activate"
            else
                echo "Python 3 not available"
                exit 1
            fi
            ;;
        *)
            echo "Python actions: list, create <name>"
            ;;
    esac
}

manage_docker() {
    local action="$1"
    
    case "$action" in
        setup)
            if ! command -v docker &> /dev/null; then
                echo "Docker not installed. Installing..."
                install_docker
            fi
            
            echo "Setting up Docker development environment..."
            
            # Create docker-compose.yml template
            cat > docker-compose.yml << EOF
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
EOF
            
            # Create Dockerfile template
            cat > Dockerfile << EOF
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF
            
            echo "✓ Docker configuration files created"
            ;;
        status)
            if command -v docker &> /dev/null; then
                echo "Docker version: $(docker --version)"
                echo "Docker status: $(systemctl is-active docker 2>/dev/null || echo 'unknown')"
                echo "Running containers: $(docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || echo 'none')"
            else
                echo "Docker not installed"
            fi
            ;;
        *)
            echo "Docker actions: setup, status"
            ;;
    esac
}

# Parse arguments
COMMAND=""
SUBCOMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        check|c)
            COMMAND="check"
            shift
            ;;
        install|i)
            COMMAND="install"
            shift
            ;;
        node|n)
            COMMAND="node"
            shift
            ;;
        python|py)
            COMMAND="python"
            shift
            ;;
        docker|d)
            COMMAND="docker"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
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

case "$COMMAND" in
    check)
        check_tools
        ;;
    install)
        if [[ -z "$SUBCOMMAND" ]]; then
            echo "Specify what to install: basic, node, python, docker"
            exit 1
        fi
        install_tool "$SUBCOMMAND"
        ;;
    node)
        manage_node "${SUBCOMMAND:-list}"
        ;;
    python)
        manage_python "${SUBCOMMAND:-list}" "${ARGS[0]:-}"
        ;;
    docker)
        manage_docker "${SUBCOMMAND:-status}"
        ;;
    "")
        show_help
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac