#!/bin/bash
set -euo pipefail

show_help() {
    cat << EOF
System Monitor - Check system health and performance

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    overview, o        Show system overview
    resources, r       Show CPU, memory, disk usage
    processes, p       Show top processes
    network, n         Show network information
    services, s        Show system services status
    logs, l           Show recent system logs
    
Options:
    -w, --watch        Continuous monitoring (5s refresh)
    -h, --help         Show this help message

Examples:
    $0 overview
    $0 resources --watch
    $0 processes
EOF
}

get_os_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    else
        uname -s
    fi
}

show_overview() {
    echo "=== System Overview ==="
    echo "OS: $(get_os_info)"
    echo "Kernel: $(uname -r)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Users: $(who | wc -l) logged in"
    echo
}

show_resources() {
    echo "=== Resource Usage ==="
    
    if command -v top &> /dev/null; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
        echo "CPU Usage: ${cpu_usage}%"
    fi
    
    command -v free &> /dev/null && free -h | grep -E "Mem|Swap"
    
    echo -e "\n=== Disk Usage ==="
    df -h | grep -E "^/dev|^tmpfs" | head -10
    echo
}

show_processes() {
    echo "=== Top Processes ==="
    if command -v ps &> /dev/null; then
        ps aux --sort=-%cpu | head -11
    else
        echo "ps command not available"
    fi
    echo
}

show_network() {
    echo "=== Network Information ==="
    
    # Network interfaces
    if command -v ip &> /dev/null; then
        echo "Network Interfaces:"
        ip addr show | grep -E "^[0-9]|inet " | head -10
    elif command -v ifconfig &> /dev/null; then
        echo "Network Interfaces:"
        ifconfig | grep -E "^[a-z]|inet " | head -10
    fi
    
    echo
    
    # Network connections
    if command -v ss &> /dev/null; then
        echo "Active Connections:"
        ss -tuln | head -10
    elif command -v netstat &> /dev/null; then
        echo "Active Connections:"
        netstat -tuln | head -10
    fi
    echo
}

show_services() {
    echo "=== System Services ==="
    
    if command -v systemctl &> /dev/null; then
        echo "Failed Services:"
        systemctl --failed --no-pager 2>/dev/null || echo "No failed services"
        echo
        echo "Active Services (top 10):"
        systemctl list-units --type=service --state=active --no-pager | head -11
    else
        echo "systemctl not available"
        if command -v service &> /dev/null; then
            echo "Using service command..."
            service --status-all 2>/dev/null | head -10 || echo "Service status unavailable"
        fi
    fi
    echo
}

show_logs() {
    echo "=== Recent System Logs ==="
    
    if command -v journalctl &> /dev/null; then
        echo "Last 10 system messages:"
        journalctl -n 10 --no-pager 2>/dev/null || echo "Journal unavailable"
    elif [[ -f /var/log/syslog ]]; then
        echo "Last 10 syslog entries:"
        tail -10 /var/log/syslog 2>/dev/null || echo "Syslog unavailable"
    elif [[ -f /var/log/messages ]]; then
        echo "Last 10 system messages:"
        tail -10 /var/log/messages 2>/dev/null || echo "Messages log unavailable"
    else
        echo "No accessible system logs found"
    fi
    echo
}

monitor_loop() {
    local command="$1"
    while true; do
        clear
        echo "System Monitor - $(date)"
        echo "Press Ctrl+C to exit"
        echo
        
        case "$command" in
            overview) show_overview ;;
            resources) show_resources ;;
            processes) show_processes ;;
            network) show_network ;;
            services) show_services ;;
            logs) show_logs ;;
        esac
        
        sleep 5
    done
}

# Parse arguments
WATCH=false
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--watch)
            WATCH=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        overview|o|resources|r|processes|p|network|n|services|s|logs|l)
            COMMAND="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Default to overview if no command specified
if [[ -z "$COMMAND" ]]; then
    COMMAND="overview"
fi

# Normalize command names
case "$COMMAND" in
    o) COMMAND="overview" ;;
    r) COMMAND="resources" ;;
    p) COMMAND="processes" ;;
    n) COMMAND="network" ;;
    s) COMMAND="services" ;;
    l) COMMAND="logs" ;;
esac

if [[ "$WATCH" == true ]]; then
    monitor_loop "$COMMAND"
else
    case "$COMMAND" in
        overview) show_overview ;;
        resources) show_resources ;;
        processes) show_processes ;;
        network) show_network ;;
        services) show_services ;;
        logs) show_logs ;;
    esac
fi