#!/bin/bash
set -euo pipefail

show_help() {
    cat << 'EOF'
Log Analyzer - Parse and analyze log files

Usage: $0 [COMMAND] [FILE] [OPTIONS]

Commands:
    errors [file]           Find error patterns
    stats [file]            Generate log statistics
    tail [file]             Smart tail with filtering
    search <pattern> [file] Search for specific patterns
    rotate [file]           Rotate log files
    monitor [file]          Real-time monitoring with alerts
    
Options:
    --lines NUM            Number of lines to process (default: 1000)
    --since TIME           Show logs since time (1h, 1d, etc.)
    --level LEVEL          Filter by log level
    --format FORMAT        Log format (apache, nginx, json, syslog)
    -f, --follow          Follow log file
    -v, --verbose         Verbose output

Examples:
    $0 errors /var/log/nginx/error.log
    $0 stats access.log --format apache
    $0 search "404" --since 1h
    $0 monitor app.log --level error
EOF
}

LINES=1000
SINCE=""
LEVEL=""
FORMAT=""
FOLLOW=false
VERBOSE=false

detect_format() {
    local file="$1"
    
    if head -5 "$file" | grep -q '^\[.*\] \[.*\]'; then
        echo "apache"
    elif head -5 "$file" | grep -q '^{.*}$'; then
        echo "json"
    elif head -5 "$file" | grep -q '^[A-Z][a-z]{2} [0-9]'; then
        echo "syslog"
    else
        echo "generic"
    fi
}

find_errors() {
    local file="${1:-/var/log/syslog}"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; exit 1; }
    
    echo "Analyzing errors in: $file"
    
    local error_patterns=(
        "ERROR"
        "FATAL"
        "CRITICAL"
        "Exception"
        "Traceback"
        "500"
        "502"
        "503"
        "504"
        "failed"
        "denied"
        "timeout"
    )
    
    local temp_file=$(mktemp)
    
    for pattern in "${error_patterns[@]}"; do
        grep -i "$pattern" "$file" 2>/dev/null >> "$temp_file" || true
    done
    
    if [[ -s "$temp_file" ]]; then
        echo "Error summary:"
        sort "$temp_file" | uniq -c | sort -nr | head -20
        
        echo -e "\nRecent errors:"
        tail -20 "$temp_file"
    else
        echo "No errors found"
    fi
    
    rm "$temp_file"
}

generate_stats() {
    local file="${1:-/var/log/nginx/access.log}"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; exit 1; }
    
    local format="${FORMAT:-$(detect_format "$file")}"
    
    echo "Log statistics for: $file"
    echo "Format detected: $format"
    echo "File size: $(du -h "$file" | cut -f1)"
    echo "Total lines: $(wc -l < "$file")"
    echo
    
    case "$format" in
        apache|nginx)
            echo "=== HTTP Status Codes ==="
            awk '{print $9}' "$file" | sort | uniq -c | sort -nr | head -10
            
            echo -e "\n=== Top IPs ==="
            awk '{print $1}' "$file" | sort | uniq -c | sort -nr | head -10
            
            echo -e "\n=== Top URLs ==="
            awk '{print $7}' "$file" | sort | uniq -c | sort -nr | head -10
            
            echo -e "\n=== User Agents ==="
            awk -F'"' '{print $6}' "$file" | sort | uniq -c | sort -nr | head -5
            ;;
        json)
            echo "=== JSON Log Analysis ==="
            jq -r '.level' "$file" 2>/dev/null | sort | uniq -c | sort -nr || \
                echo "Unable to parse JSON logs"
            ;;
        syslog)
            echo "=== Syslog Analysis ==="
            awk '{print $5}' "$file" | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
            ;;
        *)
            echo "=== Generic Analysis ==="
            echo "Most common words:"
            tr ' ' '\n' < "$file" | tr '[:upper:]' '[:lower:]' | \
                grep -E '^[a-z]{3,}$' | sort | uniq -c | sort -nr | head -10
            ;;
    esac
}

smart_tail() {
    local file="${1:-/var/log/syslog}"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; exit 1; }
    
    local tail_cmd="tail"
    [[ "$FOLLOW" == true ]] && tail_cmd="$tail_cmd -f"
    tail_cmd="$tail_cmd -n $LINES"
    
    if [[ -n "$LEVEL" ]]; then
        eval "$tail_cmd '$file'" | grep -i "$LEVEL"
    elif [[ -n "$SINCE" ]]; then
        local since_date=$(date -d "$SINCE ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
        if [[ -n "$since_date" ]]; then
            eval "$tail_cmd '$file'" | awk -v since="$since_date" '$0 >= since'
        else
            eval "$tail_cmd '$file'"
        fi
    else
        eval "$tail_cmd '$file'"
    fi
}

search_logs() {
    local pattern="$1"
    local file="${2:-/var/log/syslog}"
    
    [[ -z "$pattern" ]] && { echo "Search pattern required"; exit 1; }
    [[ ! -f "$file" ]] && { echo "File not found: $file"; exit 1; }
    
    echo "Searching for '$pattern' in: $file"
    
    local grep_cmd="grep -i"
    [[ "$VERBOSE" == true ]] && grep_cmd="$grep_cmd -n"
    
    if [[ -n "$SINCE" ]]; then
        local since_date=$(date -d "$SINCE ago" '+%Y-%m-%d' 2>/dev/null || echo "")
        if [[ -n "$since_date" ]]; then
            grep_cmd="$grep_cmd --after-context=2 --before-context=2"
        fi
    fi
    
    eval "$grep_cmd '$pattern' '$file'" | head -50
}

rotate_logs() {
    local file="${1:-/var/log/app.log}"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; exit 1; }
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local rotated_file="${file}.${timestamp}"
    
    echo "Rotating log: $file -> $rotated_file"
    
    cp "$file" "$rotated_file"
    > "$file"
    
    gzip "$rotated_file" &
    
    echo "✓ Log rotated and compressed"
    
    echo "Cleaning old rotated logs (keeping 10 most recent)..."
    ls -t "${file}".*.gz 2>/dev/null | tail -n +11 | xargs rm -f
}

monitor_logs() {
    local file="${1:-/var/log/syslog}"
    
    [[ ! -f "$file" ]] && { echo "File not found: $file"; exit 1; }
    
    echo "Monitoring: $file"
    echo "Press Ctrl+C to stop"
    
    tail -f "$file" | while read -r line; do
        local timestamp=$(date '+%H:%M:%S')
        
        if [[ -n "$LEVEL" ]]; then
            if echo "$line" | grep -qi "$LEVEL"; then
                echo "[$timestamp] $line"
                
                if echo "$line" | grep -qi "error\|critical\|fatal"; then
                    echo "🚨 ALERT: Critical log detected!" >&2
                fi
            fi
        else
            echo "[$timestamp] $line"
        fi
    done
}

COMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        errors|stats|tail|search|rotate|monitor)
            COMMAND="$1"
            shift
            ;;
        --lines)
            LINES="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --level)
            LEVEL="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        -f|--follow)
            FOLLOW=true
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
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

case "$COMMAND" in
    errors) find_errors "${ARGS[0]:-}" ;;
    stats) generate_stats "${ARGS[0]:-}" ;;
    tail) smart_tail "${ARGS[0]:-}" ;;
    search) search_logs "${ARGS[0]:-}" "${ARGS[1]:-}" ;;
    rotate) rotate_logs "${ARGS[0]:-}" ;;
    monitor) monitor_logs "${ARGS[0]:-}" ;;
    "") show_help ;;
    *) echo "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac