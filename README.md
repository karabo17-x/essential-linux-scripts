# Essential Linux Bash Scripts Collection

[![GitHub stars](https://img.shields.io/github/stars/Moon9t/essential-linux-scripts?style=flat-square)](https://github.com/Moon9t/essential-linux-scripts/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/Moon9t/essential-linux-scripts?style=flat-square)](https://github.com/Moon9t/essential-linux-scripts/network)
[![GitHub issues](https://img.shields.io/github/issues/Moon9t/essential-linux-scripts?style=flat-square)](https://github.com/Moon9t/essential-linux-scripts/issues)
[![GitHub license](https://img.shields.io/github/license/Moon9t/essential-linux-scripts?style=flat-square)](https://github.com/Moon9t/essential-linux-scripts/blob/main/LICENSE)
[![Bash](https://img.shields.io/badge/Language-Bash-green?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue?style=flat-square&logo=linux)](https://www.linux.org/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-orange?style=flat-square&logo=amazon-aws)](https://aws.amazon.com/)
[![GCP](https://img.shields.io/badge/Cloud-GCP-blue?style=flat-square&logo=google-cloud)](https://cloud.google.com/)
[![Docker](https://img.shields.io/badge/Container-Docker-blue?style=flat-square&logo=docker)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-blue?style=flat-square&logo=kubernetes)](https://kubernetes.io/)
[![Scripts](https://img.shields.io/badge/Scripts-16-brightgreen?style=flat-square)](https://github.com/Moon9t/essential-linux-scripts)
[![Maintained](https://img.shields.io/badge/Maintained-Yes-green?style=flat-square)](https://github.com/Moon9t/essential-linux-scripts/graphs/commit-activity)

A curated collection of bash scripts for developers, daily users, and system administrators that work seamlessly on both PC and server environments.

## Quick Start

```bash
# Make all scripts executable
./setup.sh

# Or manually
chmod +x **/*.sh
```

## Scripts Overview

### Development Tools (`dev/`)
- **git-helper.sh** - Streamline git workflows with shortcuts for common operations
- **project-init.sh** - Bootstrap new projects (Node.js, Python, Go, Rust, Web)
- **env-manager.sh** - Manage development environments and dependencies

### System Administration (`admin/`)
- **system-monitor.sh** - Comprehensive system health monitoring and diagnostics

### Daily Utilities (`utils/`)
- **file-organizer.sh** - Organize files by type, date, or size automatically
- **backup-helper.sh** - Simple and reliable backup solution with compression
- **system-info.sh** - Display comprehensive system information
- **log-analyzer.sh** - Parse and analyze log files with smart filtering

### Network Tools (`network/`)
- **connection-test.sh** - Network diagnostics, speed tests, and connectivity checks

### Cloud Tools (`cloud/`)
- **aws-helper.sh** - AWS operations (EC2, S3, CloudWatch, deployments)
- **gcp-helper.sh** - Google Cloud Platform automation (Compute, Storage, Cloud Run)

### DevOps Tools (`devops/`)
- **docker-manager.sh** - Container lifecycle management and automation
- **k8s-helper.sh** - Kubernetes cluster management and operations
- **ci-helper.sh** - Continuous Integration pipeline automation
- **terraform-helper.sh** - Infrastructure as Code management

## Quick Examples

```bash
# Git operations
./dev/git-helper.sh qc "Fix authentication bug"
./dev/git-helper.sh sync

# Project setup
./dev/project-init.sh node my-api
./dev/project-init.sh python data-processor

# System monitoring
./admin/system-monitor.sh overview
./admin/system-monitor.sh resources --watch

# File management
./utils/file-organizer.sh by-type ~/Downloads
./utils/backup-helper.sh create ~/Documents ~/backups --compress

# Network testing
./network/connection-test.sh ping google.com
./network/connection-test.sh port github.com 443

# System info
./utils/system-info.sh --short

# Cloud operations
./cloud/aws-helper.sh ec2 list --region us-west-2
./cloud/gcp-helper.sh compute start my-instance

# DevOps automation
./devops/docker-manager.sh build myapp
./devops/k8s-helper.sh pods -n production
./devops/ci-helper.sh init github
./devops/terraform-helper.sh plan --var-file prod.tfvars

# Log analysis
./utils/log-analyzer.sh errors /var/log/nginx/error.log
./utils/log-analyzer.sh monitor app.log --level error
```

## Installation Options

### Option 1: Run setup script (recommended)
```bash
./setup.sh
```

### Option 2: Manual setup
```bash
# Make executable
chmod +x **/*.sh

# Add to PATH (optional)
echo 'export PATH=$PATH:'$(pwd) >> ~/.bashrc
source ~/.bashrc
```

### Option 3: System-wide installation
```bash
# Copy to system directory
sudo cp -r . /opt/bash-scripts
sudo ln -sf /opt/bash-scripts/dev/git-helper.sh /usr/local/bin/git-helper
# ... repeat for other scripts
```

## Features

- **Cross-distribution compatibility** - Works on Ubuntu, CentOS, Arch, Alpine, and more
- **Comprehensive help** - Every script has detailed help with `-h` or `--help`
- **Error handling** - Robust error checking and user-friendly messages
- **Flexible options** - Multiple output formats, dry-run modes, verbose logging
- **No dependencies** - Uses only standard Linux tools and bash built-ins

## Compatibility

Tested and verified on:
- Ubuntu 20.04+ / Debian 10+
- CentOS 7+ / RHEL 7+
- Fedora 30+
- Arch Linux
- Alpine Linux 3.12+
- Amazon Linux 2