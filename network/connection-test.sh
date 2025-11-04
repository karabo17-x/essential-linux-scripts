#!/bin/bash

# Connection Test - Network diagnostics and connectivity testing
# Compatible with all Linux distributions

set -euo pipefail

show_help() {
    cat << EOF
Connection Test - Network diagnostics and connectivity testing

Usage: $0 [COMMAND] [TARGET] [OPTIONS]

Commands:
    ping, p            Test basic connectivity
    port, pt           Test specific port connectivity
    speed, s           Test internet speed (basic)
    dns, d             Test DNS resolution
    trace, t           Trace route to destination
    scan, sc           Scan local network for devices
    
Options:
    -c, --count NUM    Number of ping attempts (default: 4)
    -t, --timeout SEC  Timeout in seconds (default: 5)
    -v, --verbose      Show detailed output
    -h, --help         Show this help message

Examples:
    $0 ping google.com
    $0 port github.com 443
    $0 dns cloudflare.com
    $0 scan
EOF
}

# Default values
COUNT=4
TIMEOUT=5
VERBOSE=false

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "  $1"
    fi
}

test_ping() {
    local target="$1"
    echo "Testing connectivity to $target..."
    
    if command -v ping &> /dev/null; then
        if ping -c "$COUNT" -W "$TIMEOUT" "$target" &> /dev/null; then
            echo "✓ $target is reachable"
            
            if [[ "$VERBOSE" == true ]]; then
                local avg_time=$(ping -c "$COUNT" -W "$TIMEOUT" "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' 2>/dev/null || echo "N/A")
                echo "  Average response time: ${avg_time}ms"
            fi
        else
            echo "✗ $target is not reachable"
            return 1
        fi
    else
        echo "ping command not available"
        return 1
    fi
}

test_port() {
    local host="$1"
    local port="$2"
    
    echo "Testing port $port on $host..."
    
    if command -v nc &> /dev/null; then
        if nc -z -w "$TIMEOUT" "$host" "$port" 2>/dev/null; then
            echo "✓ Port $port is open on $host"
        else
            echo "✗ Port $port is closed or filtered on $host"
            return 1
        fi
    elif command -v telnet &> /dev/null; then
        if timeout "$TIMEOUT" telnet "$host" "$port" </dev/null &>/dev/null; then
            echo "✓ Port $port is open on $host"
        else
            echo "✗ Port $port is closed or filtered on $host"
            return 1
        fi
    else
        # Fallback using /dev/tcp
        if timeout "$TIMEOUT" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            echo "✓ Port $port is open on $host"
        else
            echo "✗ Port $port is closed or filtered on $host"
            return 1
        fi
    fi
}

test_speed() {
    echo "Testing internet speed (basic)..."
    
    # Test download speed using curl
    if command -v curl &> /dev/null; then
        echo "Testing download speed..."
        local start_time=$(date +%s.%N)
        
        # Download a small file from a fast CDN
        if curl -s -o /dev/null -w "%{speed_download}" "http://speedtest.ftp.otenet.gr/files/test1Mb.db" 2>/dev/null | grep -q .; then
            local speed=$(curl -s -o /dev/null -w "%{speed_download}" "http://speedtest.ftp.otenet.gr/files/test1Mb.db" 2>/dev/null)
            local speed_mbps=$(echo "scale=2; $speed / 1024 / 1024 * 8" | bc 2>/dev/null || echo "N/A")
            echo "✓ Approximate download speed: ${speed_mbps} Mbps"
        else
            echo "✗ Speed test failed"
        fi
    else
        echo "curl not available for speed test"
    fi
    
    # Test latency to common servers
    echo "Testing latency to common servers..."
    local servers=("8.8.8.8" "1.1.1.1" "google.com")
    
    for server in "${servers[@]}"; do
        if command -v ping &> /dev/null; then
            local latency=$(ping -c 1 -W 2 "$server" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "N/A")
            echo "  $server: ${latency}ms"
        fi
    done
}

test_dns() {
    local target="$1"
    echo "Testing DNS resolution for $target..."
    
    if command -v nslookup &> /dev/null; then
        local result=$(nslookup "$target" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
        if [[ -n "$result" ]]; then
            echo "✓ DNS resolution successful: $target -> $result"
            
            if [[ "$VERBOSE" == true ]]; then
                echo "Full DNS lookup:"
                nslookup "$target" 2>/dev/null | grep -E "Name:|Address:"
            fi
        else
            echo "✗ DNS resolution failed for $target"
            return 1
        fi
    elif command -v dig &> /dev/null; then
        local result=$(dig +short "$target" 2>/dev/null | head -1)
        if [[ -n "$result" ]]; then
            echo "✓ DNS resolution successful: $target -> $result"
        else
            echo "✗ DNS resolution failed for $target"
            return 1
        fi
    else
        # Fallback using getent
        if getent hosts "$target" &>/dev/null; then
            local result=$(getent hosts "$target" | awk '{print $1}')
            echo "✓ DNS resolution successful: $target -> $result"
        else
            echo "✗ DNS resolution failed for $target"
            return 1
        fi
    fi
}

trace_route() {
    local target="$1"
    echo "Tracing route to $target..."
    
    if command -v traceroute &> /dev/null; then
        traceroute -w "$TIMEOUT" "$target" 2>/dev/null || echo "Traceroute failed"
    elif command -v tracepath &> /dev/null; then
        tracepath "$target" 2>/dev/null || echo "Tracepath failed"
    else
        echo "No traceroute utility available"
        return 1
    fi
}

scan_network() {
    echo "Scanning local network for devices..."
    
    # Get local network range
    local network=""
    if command -v ip &> /dev/null; then
        network=$(ip route | grep -E "192\.168\.|10\.|172\." | grep "/" | head -1 | awk '{print $1}' 2>/dev/null)
    elif command -v route &> /dev/null; then
        network=$(route -n | grep -E "192\.168\.|10\.|172\." | head -1 | awk '{print $1}' 2>/dev/null)
    fi
    
    if [[ -z "$network" ]]; then
        echo "Could not determine local network range"
        return 1
    fi
    
    echo "Scanning network: $network"
    
    if command -v nmap &> /dev/null; then
        nmap -sn "$network" 2>/dev/null | grep -E "Nmap scan report|MAC Address"
    else
        # Fallback ping sweep
        local base_ip=$(echo "$network" | cut -d'/' -f1 | cut -d'.' -f1-3)
        echo "Performing ping sweep on $base_ip.1-254..."
        
        for i in {1..254}; do
            local ip="$base_ip.$i"
            if ping -c 1 -W 1 "$ip" &>/dev/null; then
                echo "✓ $ip is alive"
            fi
        done &
        wait
    fi
}

# Parse arguments
COMMAND=""
TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        ping|p)
            COMMAND="ping"
            shift
            ;;
        port|pt)
            COMMAND="port"
            shift
            ;;
        speed|s)
            COMMAND="speed"
            shift
            ;;
        dns|d)
            COMMAND="dns"
            shift
            ;;
        trace|t)
            COMMAND="trace"
            shift
            ;;
        scan|sc)
            COMMAND="scan"
            shift
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
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
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TARGET" ]]; then
                TARGET="$1"
            elif [[ "$COMMAND" == "port" && -z "${PORT:-}" ]]; then
                PORT="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    echo "Error: No command specified"
    show_help
    exit 1
fi

case "$COMMAND" in
    ping)
        if [[ -z "$TARGET" ]]; then
            echo "Error: Target required for ping test"
            exit 1
        fi
        test_ping "$TARGET"
        ;;
    port)
        if [[ -z "$TARGET" || -z "${PORT:-}" ]]; then
            echo "Error: Host and port required for port test"
            exit 1
        fi
        test_port "$TARGET" "$PORT"
        ;;
    speed)
        test_speed
        ;;
    dns)
        if [[ -z "$TARGET" ]]; then
            echo "Error: Target required for DNS test"
            exit 1
        fi
        test_dns "$TARGET"
        ;;
    trace)
        if [[ -z "$TARGET" ]]; then
            echo "Error: Target required for trace route"
            exit 1
        fi
        trace_route "$TARGET"
        ;;
    scan)
        scan_network
        ;;
esac