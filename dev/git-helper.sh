#!/bin/bash
set -euo pipefail

show_help() {
    cat << EOF
Git Helper - Streamline your git workflow

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    quick-commit, qc    Quick add, commit with message
    branch-clean, bc    Clean merged branches
    repo-status, rs     Show detailed repo status
    sync, s            Pull latest and push current branch
    undo-commit, uc    Undo last commit (keep changes)
    
Options:
    -h, --help         Show this help message

Examples:
    $0 qc "Fix bug in user authentication"
    $0 bc
    $0 sync
EOF
}

quick_commit() {
    [[ -z "${1:-}" ]] && { echo "Error: Commit message required"; exit 1; }
    
    git add .
    git commit -m "$1"
    echo "✓ Changes committed: $1"
}

branch_clean() {
    echo "Cleaning merged branches..."
    git branch --merged | grep -v "\*\|main\|master\|develop" | xargs -n 1 git branch -d 2>/dev/null || true
    echo "✓ Merged branches cleaned"
}

repo_status() {
    echo "=== Repository Status ==="
    echo "Branch: $(git branch --show-current)"
    echo "Remote: $(git remote get-url origin 2>/dev/null || echo 'No remote')"
    echo
    echo "=== File Status ==="
    git status --short
    echo
    echo "=== Recent Commits ==="
    git log --oneline -5
}

sync_repo() {
    local current_branch=$(git branch --show-current)
    echo "Syncing branch: $current_branch"
    
    git pull origin "$current_branch" || {
        echo "Pull failed, trying to pull from main/master first..."
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
    }
    
    if git diff --quiet && git diff --staged --quiet; then
        echo "No local changes to push"
    else
        git push origin "$current_branch"
        echo "✓ Changes pushed to $current_branch"
    fi
}

undo_commit() {
    git reset --soft HEAD~1
    echo "✓ Last commit undone (changes preserved)"
}

case "${1:-}" in
    quick-commit|qc)
        quick_commit "${2:-}"
        ;;
    branch-clean|bc)
        branch_clean
        ;;
    repo-status|rs)
        repo_status
        ;;
    sync|s)
        sync_repo
        ;;
    undo-commit|uc)
        undo_commit
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac