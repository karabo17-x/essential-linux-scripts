#!/bin/bash
set -euo pipefail


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok() {
    echo -e "${GREEN}OK${RESET} $1"
}
warn() {
    echo -e "${YELLOW}WARN${RESET} $1"
}
err() {
    echo -e "${RED}ERROR${RESET} $1"
}
hdr() {
    echo -e "${CYAN}${BOLD}$1${RESET}"; printf "%.0s-" {1..50}; echo
}

#configurable alert
CPU_WARN=80
MEM_WARN=85
DISK_WARN=90
LOAD_WARN=4

#optional log-to-file
#LOG_FILE=/var/log/sysmon.log ./system_monitor.sh resources

LOG_FILE="${LOG_FILE:-}"
log_output(){
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
}

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
#additions 
show_overview() {
    hdr "===System Overview==="
    echo "OS: $(get_os_info)"
    echo "Kernel: $(uname -r)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Users: $(who | wc -l) logged in"

    #installed RAM
    if [[ -f /proc/meminfo ]]; then
        total_ram=$(awk '/MemTotal/ {printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
        echo "Installed RAM: $total_ram"
    fi

    #Public IP
    if command -v curl &> /dev/null; then
        pub_ip=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo "unavailable")
        echo "Public IP: $pub_ip"
    fi

    echo
}

#show_resources - original + threshold warnings
show_resources() {
    hdr "=== Resource Usage ==="
    #CPU 
    if command -v top &> /dev/null; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
        #added color-code CPU reading
        cpu_int=${cpu_usage%.*}
        if(( cpu_int >= CPU_WARN ));then
            err "CPU Usage: ${cpu_usage}% (threshold: ${CPU_WARN}%)"
            log_output "HIGH CPU: ${cpu_usage}%"
        elif (( cpu_int >= CPU_WARN - 20 ));then
            warn "CPU Usage: ${cpu_usage}%"
        else
            ok "CPU Usage: ${cpu_usage}%"
        fi    
    fi
    
    #Memory
    if command -v free &> /dev/null; then
    # compute mem
        read -r total used <<< $(free -m | awk '/Mem:/ {print $2, $3}')
        mem_pct=$(( used * 100 / total ))
        free_out=$(free -h | grep -E "Mem|Swap")
        echo "$free_out"
        if (( mem_pct >= MEM_WARN )); then
            err "Memory pressure: ${mem_pct}% used (threshold: ${MEM_WARN}%)"
            log_output "HIGH Memory: ${mem_pct}%"
        elif (( mem_pct >= MEM_WARN - 20 )); then
            warn "Memory pressure: ${mem_pct}% used"
        else
            ok "Memory pressure: ${mem_pct}%"
        fi    
    fi

    hdr "=== Disk Usage ==="
    while IFS= read -r line;do
        pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
        if [[ "$pct" =~ ^[0-9]+$ ]];then
            if ((pct >= DISK_WARN));then
                err "$line"
                log_output "HIGH Disk: $line"
            elif ((pct >= DISK_WARN - 20));then
                warn "$line"
            else
                ok "$line"
            fi
        fi
    done < <(df -h | grep -E "^/dev|^tmpfs" | head -10)

    echo
    
}

show_processes() {
    hdr "=== Process Information ==="
    if command -v ps &> /dev/null; then
        ps aux --sort=-%cpu | head -11
    else
        echo "ps command not available"
    fi
    echo
}

show_network() {
    hdr "=== Network Information ==="
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

    #default gateway & DNS servers
    echo
    echo "Default Gateway:"
    ip route show default 2>/dev/null || route -n 2>/dev/null | head -3 || echo "Unavailable"
    echo
    echo "DNS Servers:"
    if [[ -f /etc/resolv.conf ]]; then
        grep "^nameserver" /etc/resolv.conf || echo "No DNS servers found"
    else
        echo "resolv.conf not found"
    fi
    echo
}

show_services() {
    hdr "=== System Services ==="
    
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
    hdr "=== Recent System Logs ==="
    
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

#show temperature
show_temperature() {
    hdr "===Temperature==="
    found=0
    if command -v sensors &>/dev/null;then
        sensors 2>/dev/null && found=1
    fi
    if [[ -d /sys/class/thermal ]];then
        for zone in /sys/class/thermal/thermal_zone*/;do
            type_file="${zone}type"
            temp_file="${zone}temp"
            [[ -r "$type_file" ]] || continue
            zone_type=$(cat "$type_file" 2>/dev/null || echo "unknown")
            temp_raw=$(cat "$temp_file" 2>/dev/null || echo "0")
            temp_c=$(( temp_raw / 1000 ))
            if((temp_c >= 85));then
                err "Temperature: ${zone_type} ${temp_c}°C (threshold: 80°C)"
                log_output "HIGH Temp: ${zone_type} ${temp_c}°C"
            elif (( temp_c >= 60 ));then
                warn "Temperature: ${zone_type} ${temp_c}°C"
            else
                ok "Temperature: ${zone_type} ${temp_c}°C"
            fi
            found=1
        done
    fi
}

monitor_loop() {
    local command="$1"
    while true; do
        clear
        echo -e "${BOLD}System Monitor - $(date)${RESET}"
        echo "Press Ctrl+C to exit"
        case "$command" in
            overview) show_overview ;;
            resources) show_resources ;;
            processes) show_processes ;;
            network) show_network ;;
            services) show_services ;;
            logs) show_logs ;;
            temperature) show_temperature ;;
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
        overview|o|resources|r|processes|p|network|n|services|s|logs|l|temperature|t)
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
    t) COMMAND="temperature" ;;
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
        temperature) show_temperature ;;
    esac
fi