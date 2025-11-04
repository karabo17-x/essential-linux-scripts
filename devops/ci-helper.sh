#!/bin/bash
set -euo pipefail

show_help() {
    cat << 'EOF'
CI Helper - Continuous Integration automation

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    init <type>             Initialize CI configuration
    test                    Run test suite with coverage
    build                   Build application/container
    lint                    Run linting and code quality checks
    security                Security vulnerability scan
    deploy <env>            Deploy to environment
    pipeline                Show pipeline status
    
Types: github, gitlab, jenkins, azure

Options:
    --env ENV              Environment (dev/staging/prod)
    --skip-tests          Skip test execution
    --parallel            Run jobs in parallel
    -v, --verbose         Verbose output

Examples:
    $0 init github
    $0 test --parallel
    $0 build --env production
    $0 security
EOF
}

ENVIRONMENT="dev"
SKIP_TESTS=false
PARALLEL=false
VERBOSE=false

init_ci() {
    local type="$1"
    [[ -z "$type" ]] && { echo "CI type required: github, gitlab, jenkins, azure"; exit 1; }
    
    case "$type" in
        github)
            mkdir -p .github/workflows
            cat > .github/workflows/ci.yml << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    - run: npm ci
    - run: npm test
    - run: npm run build

  security:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run security audit
      run: npm audit --audit-level moderate

  deploy:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - uses: actions/checkout@v3
    - name: Deploy to production
      run: echo "Deploy step here"
EOF
            echo "✓ GitHub Actions workflow created"
            ;;
        gitlab)
            cat > .gitlab-ci.yml << 'EOF'
stages:
  - test
  - build
  - deploy

variables:
  NODE_VERSION: "18"

test:
  stage: test
  image: node:$NODE_VERSION
  script:
    - npm ci
    - npm test
    - npm run lint
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

deploy:
  stage: deploy
  script:
    - echo "Deploy to $CI_ENVIRONMENT_NAME"
  only:
    - main
EOF
            echo "✓ GitLab CI configuration created"
            ;;
        jenkins)
            cat > Jenkinsfile << 'EOF'
pipeline {
    agent any
    
    tools {
        nodejs '18'
    }
    
    stages {
        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'npm test'
                    }
                }
                stage('Lint') {
                    steps {
                        sh 'npm run lint'
                    }
                }
            }
        }
        
        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh 'echo "Deploy step"'
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
EOF
            echo "✓ Jenkins pipeline created"
            ;;
        azure)
            cat > azure-pipelines.yml << 'EOF'
trigger:
- main

pool:
  vmImage: ubuntu-latest

variables:
  nodeVersion: '18.x'

stages:
- stage: Test
  jobs:
  - job: TestJob
    steps:
    - task: NodeTool@0
      inputs:
        versionSpec: $(nodeVersion)
    - script: npm ci
      displayName: 'Install dependencies'
    - script: npm test
      displayName: 'Run tests'

- stage: Build
  dependsOn: Test
  jobs:
  - job: BuildJob
    steps:
    - script: npm run build
      displayName: 'Build application'

- stage: Deploy
  dependsOn: Build
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
  jobs:
  - deployment: DeployJob
    environment: 'production'
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploy step"
EOF
            echo "✓ Azure Pipelines configuration created"
            ;;
        *)
            echo "Unknown CI type: $type"
            exit 1
            ;;
    esac
}

run_tests() {
    echo "Running test suite..."
    
    local test_cmd=""
    
    if [[ -f "package.json" ]]; then
        test_cmd="npm test"
        [[ "$PARALLEL" == true ]] && test_cmd="$test_cmd -- --parallel"
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        test_cmd="python -m pytest"
        [[ "$PARALLEL" == true ]] && test_cmd="$test_cmd -n auto"
    elif [[ -f "go.mod" ]]; then
        test_cmd="go test ./..."
        [[ "$PARALLEL" == true ]] && test_cmd="$test_cmd -parallel 4"
    elif [[ -f "Cargo.toml" ]]; then
        test_cmd="cargo test"
    else
        echo "No recognized test framework found"
        exit 1
    fi
    
    echo "Executing: $test_cmd"
    eval "$test_cmd"
    
    echo "✓ Tests completed"
    
    if command -v coverage >/dev/null 2>&1; then
        echo "Generating coverage report..."
        coverage report
    fi
}

build_application() {
    echo "Building application for environment: $ENVIRONMENT"
    
    if [[ -f "Dockerfile" ]]; then
        local tag="app:$ENVIRONMENT-$(date +%s)"
        echo "Building Docker image: $tag"
        docker build -t "$tag" .
        echo "✓ Docker image built: $tag"
        
    elif [[ -f "package.json" ]]; then
        echo "Building Node.js application..."
        npm run build
        echo "✓ Node.js build completed"
        
    elif [[ -f "go.mod" ]]; then
        echo "Building Go application..."
        go build -o app .
        echo "✓ Go build completed"
        
    elif [[ -f "Cargo.toml" ]]; then
        echo "Building Rust application..."
        cargo build --release
        echo "✓ Rust build completed"
        
    else
        echo "No recognized build system found"
        exit 1
    fi
}

run_linting() {
    echo "Running code quality checks..."
    
    local lint_commands=()
    
    if [[ -f "package.json" ]]; then
        command -v eslint >/dev/null && lint_commands+=("eslint .")
        command -v prettier >/dev/null && lint_commands+=("prettier --check .")
    fi
    
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        command -v flake8 >/dev/null && lint_commands+=("flake8 .")
        command -v black >/dev/null && lint_commands+=("black --check .")
        command -v mypy >/dev/null && lint_commands+=("mypy .")
    fi
    
    if [[ -f "go.mod" ]]; then
        lint_commands+=("go fmt ./...")
        command -v golint >/dev/null && lint_commands+=("golint ./...")
    fi
    
    if [[ -f "Cargo.toml" ]]; then
        lint_commands+=("cargo fmt --check")
        lint_commands+=("cargo clippy -- -D warnings")
    fi
    
    if [[ ${#lint_commands[@]} -eq 0 ]]; then
        echo "No linting tools configured"
        return
    fi
    
    for cmd in "${lint_commands[@]}"; do
        echo "Running: $cmd"
        eval "$cmd" || echo "⚠ Linting issues found in: $cmd"
    done
    
    echo "✓ Linting completed"
}

security_scan() {
    echo "Running security vulnerability scan..."
    
    local scan_commands=()
    
    if [[ -f "package.json" ]]; then
        scan_commands+=("npm audit")
    fi
    
    if [[ -f "requirements.txt" ]]; then
        command -v safety >/dev/null && scan_commands+=("safety check")
    fi
    
    if [[ -f "go.mod" ]]; then
        command -v gosec >/dev/null && scan_commands+=("gosec ./...")
    fi
    
    if [[ -f "Cargo.toml" ]]; then
        command -v cargo-audit >/dev/null && scan_commands+=("cargo audit")
    fi
    
    command -v trivy >/dev/null && [[ -f "Dockerfile" ]] && scan_commands+=("trivy fs .")
    
    if [[ ${#scan_commands[@]} -eq 0 ]]; then
        echo "No security scanning tools available"
        return
    fi
    
    for cmd in "${scan_commands[@]}"; do
        echo "Running: $cmd"
        eval "$cmd" || echo "⚠ Security issues found in: $cmd"
    done
    
    echo "✓ Security scan completed"
}

deploy_application() {
    local env="$1"
    [[ -z "$env" ]] && env="$ENVIRONMENT"
    
    echo "Deploying to environment: $env"
    
    case "$env" in
        dev|development)
            echo "Deploying to development environment..."
            ;;
        staging)
            echo "Deploying to staging environment..."
            ;;
        prod|production)
            echo "Deploying to production environment..."
            read -p "Are you sure you want to deploy to production? (y/N): " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Yy]$ ]] && { echo "Deployment cancelled"; exit 0; }
            ;;
        *)
            echo "Unknown environment: $env"
            exit 1
            ;;
    esac
    
    if [[ -f "docker-compose.yml" ]]; then
        docker-compose -f docker-compose.yml -f "docker-compose.$env.yml" up -d
    elif [[ -f "k8s/$env.yaml" ]]; then
        kubectl apply -f "k8s/$env.yaml"
    else
        echo "No deployment configuration found for $env"
        exit 1
    fi
    
    echo "✓ Deployment to $env completed"
}

show_pipeline_status() {
    echo "Pipeline Status Check"
    
    if [[ -d ".git" ]]; then
        local branch=$(git branch --show-current)
        local commit=$(git rev-parse --short HEAD)
        echo "Branch: $branch"
        echo "Commit: $commit"
        
        if [[ -f ".github/workflows/ci.yml" ]]; then
            echo "GitHub Actions: Check https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
        fi
        
        if [[ -f ".gitlab-ci.yml" ]]; then
            echo "GitLab CI: Check your GitLab project pipelines"
        fi
    fi
    
    if command -v docker >/dev/null; then
        echo -e "\nDocker containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
}

COMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        init|test|build|lint|security|deploy|pipeline)
            COMMAND="$1"
            shift
            ;;
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --parallel)
            PARALLEL=true
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
    init) init_ci "${ARGS[0]:-}" ;;
    test) [[ "$SKIP_TESTS" == false ]] && run_tests ;;
    build) build_application ;;
    lint) run_linting ;;
    security) security_scan ;;
    deploy) deploy_application "${ARGS[0]:-}" ;;
    pipeline) show_pipeline_status ;;
    "") show_help ;;
    *) echo "Unknown command: $COMMAND"; show_help; exit 1 ;;
esac