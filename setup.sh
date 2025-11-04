#!/bin/bash

# Setup script for Essential Linux Bash Scripts
# Makes all scripts executable and optionally adds them to PATH

set -euo pipefail

echo "Setting up Essential Linux Bash Scripts..."

# Make all scripts executable
find . -name "*.sh" -type f -exec chmod +x {} \;
echo "✓ Made all scripts executable"

# Create symlinks for easy access (optional)
read -p "Create symlinks in /usr/local/bin for system-wide access? (requires sudo) [y/N]: " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating symlinks..."
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        echo "This requires sudo access. Please enter your password:"
    fi
    
    # Create symlinks for all scripts
    sudo ln -sf "$(pwd)/dev/git-helper.sh" /usr/local/bin/git-helper
    sudo ln -sf "$(pwd)/dev/project-init.sh" /usr/local/bin/project-init
    sudo ln -sf "$(pwd)/dev/env-manager.sh" /usr/local/bin/env-manager
    sudo ln -sf "$(pwd)/admin/system-monitor.sh" /usr/local/bin/system-monitor
    sudo ln -sf "$(pwd)/utils/file-organizer.sh" /usr/local/bin/file-organizer
    sudo ln -sf "$(pwd)/utils/backup-helper.sh" /usr/local/bin/backup-helper
    sudo ln -sf "$(pwd)/utils/system-info.sh" /usr/local/bin/system-info
    sudo ln -sf "$(pwd)/utils/log-analyzer.sh" /usr/local/bin/log-analyzer
    sudo ln -sf "$(pwd)/network/connection-test.sh" /usr/local/bin/connection-test
    sudo ln -sf "$(pwd)/cloud/aws-helper.sh" /usr/local/bin/aws-helper
    sudo ln -sf "$(pwd)/cloud/gcp-helper.sh" /usr/local/bin/gcp-helper
    sudo ln -sf "$(pwd)/devops/docker-manager.sh" /usr/local/bin/docker-manager
    sudo ln -sf "$(pwd)/devops/k8s-helper.sh" /usr/local/bin/k8s-helper
    sudo ln -sf "$(pwd)/devops/ci-helper.sh" /usr/local/bin/ci-helper
    sudo ln -sf "$(pwd)/devops/terraform-helper.sh" /usr/local/bin/terraform-helper
    
    echo "✓ Symlinks created in /usr/local/bin"
    echo "You can now run scripts directly: git-helper, project-init, system-monitor, etc."
else
    echo "Skipping symlink creation"
    echo "You can run scripts directly from their directories or add this directory to your PATH"
fi

echo
echo "Setup complete! Available scripts:"
echo "  Development: git-helper, project-init, env-manager"
echo "  System Admin: system-monitor, system-info, log-analyzer"
echo "  Utilities: file-organizer, backup-helper"
echo "  Network: connection-test"
echo "  Cloud: aws-helper, gcp-helper"
echo "  DevOps: docker-manager, k8s-helper, ci-helper, terraform-helper"
echo
echo "Run any script with -h or --help for usage information."