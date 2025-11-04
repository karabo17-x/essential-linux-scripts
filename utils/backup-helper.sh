#!/bin/bash

# Backup Helper - Simple and reliable backup solution
# Compatible with all Linux distributions

set -euo pipefail

show_help() {
    cat << EOF
Backup Helper - Create and manage backups

Usage: $0 [COMMAND] [SOURCE] [DESTINATION] [OPTIONS]

Commands:
    create, c          Create a new backup
    restore, r         Restore from backup
    list, l            List available backups
    cleanup, cl        Remove old backups
    
Options:
    -z, --compress     Compress backup (tar.gz)
    -e, --exclude DIR  Exclude directory from backup
    -k, --keep NUM     Keep only NUM recent backups (default: 5)
    -v, --verbose      Show detailed output
    -h, --help         Show this help message

Examples:
    $0 create ~/Documents ~/backups/docs
    $0 create /etc /backups/system --compress
    $0 restore ~/backups/docs/backup-2024-01-15.tar.gz ~/Documents
    $0 cleanup ~/backups --keep 3
EOF
}

# Global variables
COMPRESS=false
VERBOSE=false
KEEP_COUNT=5
EXCLUDE_DIRS=()

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "  $1"
    fi
}

create_backup() {
    local source="$1"
    local dest_dir="$2"
    
    if [[ ! -d "$source" ]]; then
        echo "Error: Source directory '$source' does not exist"
        exit 1
    fi
    
    # Create destination directory if it doesn't exist
    mkdir -p "$dest_dir"
    
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local source_name=$(basename "$source")
    local backup_name="backup-${source_name}-${timestamp}"
    
    if [[ "$COMPRESS" == true ]]; then
        local backup_file="$dest_dir/${backup_name}.tar.gz"
        echo "Creating compressed backup: $backup_file"
        
        # Build exclude options
        local exclude_opts=""
        for exclude_dir in "${EXCLUDE_DIRS[@]}"; do
            exclude_opts="$exclude_opts --exclude=$exclude_dir"
        done
        
        log "Compressing $source to $backup_file"
        if tar czf "$backup_file" $exclude_opts -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null; then
            local size=$(du -h "$backup_file" | cut -f1)
            echo "✓ Backup created successfully: $backup_file ($size)"
        else
            echo "✗ Backup failed"
            exit 1
        fi
    else
        local backup_dir="$dest_dir/$backup_name"
        echo "Creating directory backup: $backup_dir"
        
        # Build rsync exclude options
        local exclude_opts=""
        for exclude_dir in "${EXCLUDE_DIRS[@]}"; do
            exclude_opts="$exclude_opts --exclude=$exclude_dir"
        done
        
        log "Copying $source to $backup_dir"
        if command -v rsync &> /dev/null; then
            rsync -av $exclude_opts "$source/" "$backup_dir/" &>/dev/null
        else
            cp -r "$source" "$backup_dir"
        fi
        
        local size=$(du -sh "$backup_dir" | cut -f1)
        echo "✓ Backup created successfully: $backup_dir ($size)"
    fi
}

restore_backup() {
    local backup_path="$1"
    local restore_dir="$2"
    
    if [[ ! -e "$backup_path" ]]; then
        echo "Error: Backup '$backup_path' does not exist"
        exit 1
    fi
    
    echo "Restoring backup from: $backup_path"
    echo "Restore destination: $restore_dir"
    
    # Ask for confirmation
    read -p "This will overwrite existing files. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled"
        exit 0
    fi
    
    mkdir -p "$restore_dir"
    
    if [[ "$backup_path" == *.tar.gz ]]; then
        log "Extracting compressed backup"
        if tar xzf "$backup_path" -C "$restore_dir" --strip-components=1 2>/dev/null; then
            echo "✓ Backup restored successfully"
        else
            echo "✗ Restore failed"
            exit 1
        fi
    elif [[ -d "$backup_path" ]]; then
        log "Copying directory backup"
        if command -v rsync &> /dev/null; then
            rsync -av "$backup_path/" "$restore_dir/" &>/dev/null
        else
            cp -r "$backup_path"/* "$restore_dir/"
        fi
        echo "✓ Backup restored successfully"
    else
        echo "Error: Unknown backup format"
        exit 1
    fi
}

list_backups() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "Error: Backup directory '$backup_dir' does not exist"
        exit 1
    fi
    
    echo "Available backups in: $backup_dir"
    echo
    
    local found_backups=false
    
    # List compressed backups
    for backup in "$backup_dir"/backup-*.tar.gz; do
        if [[ -f "$backup" ]]; then
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$backup" 2>/dev/null)
            echo "📦 $(basename "$backup") ($size) - $date"
            found_backups=true
        fi
    done
    
    # List directory backups
    for backup in "$backup_dir"/backup-*; do
        if [[ -d "$backup" ]]; then
            local size=$(du -sh "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1 || stat -f %Sm -t %Y-%m-%d "$backup" 2>/dev/null)
            echo "📁 $(basename "$backup") ($size) - $date"
            found_backups=true
        fi
    done
    
    if [[ "$found_backups" == false ]]; then
        echo "No backups found"
    fi
}

cleanup_backups() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "Error: Backup directory '$backup_dir' does not exist"
        exit 1
    fi
    
    echo "Cleaning up old backups (keeping $KEEP_COUNT most recent)..."
    
    # Clean up compressed backups
    local compressed_backups=($(ls -t "$backup_dir"/backup-*.tar.gz 2>/dev/null || true))
    if [[ ${#compressed_backups[@]} -gt $KEEP_COUNT ]]; then
        for ((i=$KEEP_COUNT; i<${#compressed_backups[@]}; i++)); do
            log "Removing old backup: ${compressed_backups[$i]}"
            rm "${compressed_backups[$i]}"
        done
    fi
    
    # Clean up directory backups
    local dir_backups=($(ls -td "$backup_dir"/backup-* 2>/dev/null | grep -v "\.tar\.gz$" || true))
    if [[ ${#dir_backups[@]} -gt $KEEP_COUNT ]]; then
        for ((i=$KEEP_COUNT; i<${#dir_backups[@]}; i++)); do
            if [[ -d "${dir_backups[$i]}" ]]; then
                log "Removing old backup: ${dir_backups[$i]}"
                rm -rf "${dir_backups[$i]}"
            fi
        done
    fi
    
    echo "✓ Cleanup completed"
}

# Parse arguments
COMMAND=""
SOURCE=""
DESTINATION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        create|c)
            COMMAND="create"
            shift
            ;;
        restore|r)
            COMMAND="restore"
            shift
            ;;
        list|l)
            COMMAND="list"
            shift
            ;;
        cleanup|cl)
            COMMAND="cleanup"
            shift
            ;;
        -z|--compress)
            COMPRESS=true
            shift
            ;;
        -e|--exclude)
            EXCLUDE_DIRS+=("$2")
            shift 2
            ;;
        -k|--keep)
            KEEP_COUNT="$2"
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
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
            elif [[ -z "$DESTINATION" ]]; then
                DESTINATION="$1"
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
    create)
        if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
            echo "Error: Source and destination required for backup creation"
            show_help
            exit 1
        fi
        create_backup "$SOURCE" "$DESTINATION"
        ;;
    restore)
        if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
            echo "Error: Backup path and restore destination required"
            show_help
            exit 1
        fi
        restore_backup "$SOURCE" "$DESTINATION"
        ;;
    list)
        if [[ -z "$SOURCE" ]]; then
            echo "Error: Backup directory required"
            show_help
            exit 1
        fi
        list_backups "$SOURCE"
        ;;
    cleanup)
        if [[ -z "$SOURCE" ]]; then
            echo "Error: Backup directory required"
            show_help
            exit 1
        fi
        cleanup_backups "$SOURCE"
        ;;
esac