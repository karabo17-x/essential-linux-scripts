#!/bin/bash

# File Organizer - Organize files by type, date, or custom rules
# Compatible with all Linux distributions

set -euo pipefail

show_help() {
    cat << EOF
File Organizer - Organize files automatically

Usage: $0 [COMMAND] [SOURCE_DIR] [OPTIONS]

Commands:
    by-type, bt        Organize files by extension
    by-date, bd        Organize files by modification date
    by-size, bs        Organize files by size ranges
    cleanup, c         Remove empty directories and temp files
    
Options:
    -d, --dry-run      Show what would be done without making changes
    -v, --verbose      Show detailed output
    -h, --help         Show this help message

Examples:
    $0 by-type ~/Downloads
    $0 by-date ~/Documents --dry-run
    $0 cleanup /tmp --verbose
EOF
}

# Global variables
DRY_RUN=false
VERBOSE=false
SOURCE_DIR=""

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "  $1"
    fi
}

execute_command() {
    local cmd="$1"
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] $cmd"
    else
        log "Executing: $cmd"
        eval "$cmd"
    fi
}

organize_by_type() {
    local source="$1"
    
    if [[ ! -d "$source" ]]; then
        echo "Error: Directory '$source' does not exist"
        exit 1
    fi
    
    echo "Organizing files by type in: $source"
    
    # Define file type categories
    declare -A file_types=(
        ["images"]="jpg jpeg png gif bmp svg webp ico"
        ["documents"]="pdf doc docx txt rtf odt"
        ["spreadsheets"]="xls xlsx csv ods"
        ["presentations"]="ppt pptx odp"
        ["archives"]="zip rar tar gz 7z bz2 xz"
        ["audio"]="mp3 wav flac aac ogg m4a"
        ["video"]="mp4 avi mkv mov wmv flv webm"
        ["code"]="py js html css php java cpp c sh"
        ["executables"]="exe deb rpm appimage"
    )
    
    for category in "${!file_types[@]}"; do
        local extensions="${file_types[$category]}"
        local target_dir="$source/$category"
        
        for ext in $extensions; do
            local files_found=false
            for file in "$source"/*."$ext" "$source"/*."${ext^^}"; do
                if [[ -f "$file" ]]; then
                    if [[ ! -d "$target_dir" ]]; then
                        execute_command "mkdir -p '$target_dir'"
                    fi
                    execute_command "mv '$file' '$target_dir/'"
                    files_found=true
                fi
            done
            
            if [[ "$files_found" == true ]]; then
                log "Moved .$ext files to $category/"
            fi
        done
    done
    
    echo "✓ File organization by type completed"
}

organize_by_date() {
    local source="$1"
    
    if [[ ! -d "$source" ]]; then
        echo "Error: Directory '$source' does not exist"
        exit 1
    fi
    
    echo "Organizing files by date in: $source"
    
    find "$source" -maxdepth 1 -type f | while read -r file; do
        if [[ -f "$file" ]]; then
            local mod_date=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
            local year_month=$(date -d "@$mod_date" +%Y-%m 2>/dev/null || date -r "$mod_date" +%Y-%m 2>/dev/null)
            local target_dir="$source/$year_month"
            
            if [[ ! -d "$target_dir" ]]; then
                execute_command "mkdir -p '$target_dir'"
            fi
            
            execute_command "mv '$file' '$target_dir/'"
            log "Moved $(basename "$file") to $year_month/"
        fi
    done
    
    echo "✓ File organization by date completed"
}

organize_by_size() {
    local source="$1"
    
    if [[ ! -d "$source" ]]; then
        echo "Error: Directory '$source' does not exist"
        exit 1
    fi
    
    echo "Organizing files by size in: $source"
    
    find "$source" -maxdepth 1 -type f | while read -r file; do
        if [[ -f "$file" ]]; then
            local size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null)
            local category=""
            
            if [[ $size -lt 1048576 ]]; then  # < 1MB
                category="small"
            elif [[ $size -lt 104857600 ]]; then  # < 100MB
                category="medium"
            else
                category="large"
            fi
            
            local target_dir="$source/$category"
            
            if [[ ! -d "$target_dir" ]]; then
                execute_command "mkdir -p '$target_dir'"
            fi
            
            execute_command "mv '$file' '$target_dir/'"
            log "Moved $(basename "$file") to $category/ ($(numfmt --to=iec $size))"
        fi
    done
    
    echo "✓ File organization by size completed"
}

cleanup_directory() {
    local source="$1"
    
    if [[ ! -d "$source" ]]; then
        echo "Error: Directory '$source' does not exist"
        exit 1
    fi
    
    echo "Cleaning up directory: $source"
    
    # Remove empty directories
    find "$source" -type d -empty | while read -r dir; do
        if [[ "$dir" != "$source" ]]; then
            execute_command "rmdir '$dir'"
            log "Removed empty directory: $(basename "$dir")"
        fi
    done
    
    # Remove common temporary files
    local temp_patterns=("*.tmp" "*.temp" "*~" ".DS_Store" "Thumbs.db" "*.bak")
    
    for pattern in "${temp_patterns[@]}"; do
        find "$source" -name "$pattern" -type f | while read -r file; do
            execute_command "rm '$file'"
            log "Removed temp file: $(basename "$file")"
        done
    done
    
    echo "✓ Directory cleanup completed"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        by-type|bt)
            COMMAND="by-type"
            shift
            ;;
        by-date|bd)
            COMMAND="by-date"
            shift
            ;;
        by-size|bs)
            COMMAND="by-size"
            shift
            ;;
        cleanup|c)
            COMMAND="cleanup"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
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
            if [[ -z "$SOURCE_DIR" ]]; then
                SOURCE_DIR="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "${COMMAND:-}" ]]; then
    echo "Error: No command specified"
    show_help
    exit 1
fi

if [[ -z "$SOURCE_DIR" ]]; then
    echo "Error: No source directory specified"
    show_help
    exit 1
fi

case "$COMMAND" in
    by-type)
        organize_by_type "$SOURCE_DIR"
        ;;
    by-date)
        organize_by_date "$SOURCE_DIR"
        ;;
    by-size)
        organize_by_size "$SOURCE_DIR"
        ;;
    cleanup)
        cleanup_directory "$SOURCE_DIR"
        ;;
esac