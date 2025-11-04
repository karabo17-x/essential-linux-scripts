#!/bin/bash

# System Info - Comprehensive system information display
# Compatible with all Linux distributions

set -euo pipefail

show_help() {
    cat << EOF
System Info - Display comprehensive system information

Usage: $0 [OPTIONS]

Options:
    -s, --short        Show condensed information
    -j, --json         Output in JSON format
    -h, --help         Show this help message

Examples:
    $0                 Show full system information
    $0 --short         Show condensed information
    $0 --json          Output as JSON
EOF
}

get_os_info() {
    local os_name="Unknown"
    local os_version="Unknown"
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os_name="$NAME"
        os_version="$VERSION"
    elif [[ -f /etc/redhat-release ]]; then
        os_name=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        os_name="Debian $(cat /etc/debian_version)"
    fi
    
    echo "$os_name $os_version"
}

get_cpu_info() {
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
        local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        echo "$cpu_model ($cpu_cores cores)"
    else
        echo "CPU information unavailable"
    fi
}

get_memory_info() {
    if [[ -f /proc/meminfo ]]; then
        local total_mem=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local available_mem=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}' 2>/dev/null || grep "MemFree" /proc/meminfo | awk '{print $2}')
        
        # Convert KB to GB
        total_mem=$((total_mem / 1024 / 1024))
        available_mem=$((available_mem / 1024 / 1024))
        
        echo "${total_mem}GB total, ${available_mem}GB available"
    else
        echo "Memory information unavailable"
    fi
}

get_disk_info() {
    if command -v df &> /dev/null; then
        df -h / | tail -1 | awk '{print $2 " total, " $4 " available (" $5 " used)"}'
    else
        echo "Disk information unavailable"
    fi
}

get_network_info() {
    local interfaces=""
    
    if command -v ip &> /dev/null; then
        interfaces=$(ip -4 addr show | grep -E "inet.*scope global" | awk '{print $NF ": " $2}' | head -3)
    elif command -v ifconfig &> /dev/null; then
        interfaces=$(ifconfig | grep -E "inet.*broadcast" | awk '{print $2}' | head -3)
    fi
    
    if [[ -n "$interfaces" ]]; then
        echo "$interfaces"
    else
        echo "Network information unavailable"
    fi
}

show_full_info() {
    echo "=== System Information ==="
    echo "Hostname: $(hostname)"
    echo "Operating System: $(get_os_info)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo
    
    echo "=== Hardware Information ==="
    echo "CPU: $(get_cpu_info)"
    echo "Memory: $(get_memory_info)"
    echo "Root Disk: $(get_disk_info)"
    echo
    
    echo "=== Network Information ==="
    get_network_info
    echo
    
    echo "=== Software Information ==="
    echo "Shell: $SHELL"
    echo "User: $(whoami)"
    echo "Home: $HOME"
    echo "PATH: $PATH" | fold -w 80
    echo
    
    if command -v docker &> /dev/null; then
        echo "Docker: $(docker --version 2>/dev/null | head -1)"
    fi
    
    if command -v git &> /dev/null; then
        echo "Git: $(git --version)"
    fi
    
    if command -v python3 &> /dev/null; then
        echo "Python: $(python3 --version)"
    fi
    
    if command -v node &> /dev/null; then
        echo "Node.js: $(node --version)"
    fi
}

show_short_info() {
    echo "$(hostname) | $(get_os_info) | $(uname -m)"
    echo "CPU: $(get_cpu_info)"
    echo "Memory: $(get_memory_info)"
    echo "Disk: $(get_disk_info)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
}

show_json_info() {
    cat << EOF
{
  "hostname": "$(hostname)",
  "os": "$(get_os_info)",
  "kernel": "$(uname -r)",
  "architecture": "$(uname -m)",
  "uptime": "$(uptime -p 2>/dev/null || uptime)",
  "cpu": "$(get_cpu_info)",
  "memory": "$(get_memory_info)",
  "disk": "$(get_disk_info)",
  "user": "$(whoami)",
  "shell": "$SHELL",
  "timestamp": "$(date -Iseconds)"
}
EOF
}

# Parse arguments
SHORT=false
JSON=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--short)
            SHORT=true
            shift
            ;;
        -j|--json)
            JSON=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$JSON" == true ]]; then
    show_json_info
elif [[ "$SHORT" == true ]]; then
    show_short_info
else
    show_full_info
fi