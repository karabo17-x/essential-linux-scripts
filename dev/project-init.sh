#!/bin/bash

# Project Initializer - Quick project setup for different languages
# Compatible with all Linux distributions

set -euo pipefail

show_help() {
    cat << EOF
Project Initializer - Bootstrap new projects quickly

Usage: $0 [PROJECT_TYPE] [PROJECT_NAME]

Project Types:
    node, js           Node.js project with package.json
    python, py         Python project with virtual environment
    go                 Go module project
    rust, rs           Rust project with Cargo
    web                Static web project (HTML/CSS/JS)
    
Options:
    -h, --help         Show this help message

Examples:
    $0 node my-api
    $0 python data-processor
    $0 go microservice
EOF
}

create_node_project() {
    local name="$1"
    mkdir -p "$name"/{src,tests,docs}
    cd "$name"
    
    cat > package.json << EOF
{
  "name": "$name",
  "version": "1.0.0",
  "description": "",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "node --watch src/index.js",
    "test": "echo \\"Error: no test specified\\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "MIT"
}
EOF
    
    echo 'console.log("Hello, World!");' > src/index.js
    echo "node_modules/" > .gitignore
    echo "# $name" > README.md
    
    echo "✓ Node.js project '$name' created"
}

create_python_project() {
    local name="$1"
    mkdir -p "$name"/{src,tests,docs}
    cd "$name"
    
    cat > requirements.txt << EOF
# Add your dependencies here
EOF
    
    cat > src/main.py << EOF
#!/usr/bin/env python3
"""
Main module for $name
"""

def main():
    print("Hello, World!")

if __name__ == "__main__":
    main()
EOF
    
    cat > .gitignore << EOF
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.venv/
.env
EOF
    
    echo "# $name" > README.md
    
    if command -v python3 &> /dev/null; then
        python3 -m venv venv
        echo "✓ Virtual environment created. Activate with: source venv/bin/activate"
    fi
    
    echo "✓ Python project '$name' created"
}

create_go_project() {
    local name="$1"
    mkdir -p "$name"
    cd "$name"
    
    go mod init "$name" 2>/dev/null || {
        echo "Go not installed, creating basic structure..."
        mkdir -p cmd pkg internal
    }
    
    cat > main.go << EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF
    
    echo "# $name" > README.md
    echo "✓ Go project '$name' created"
}

create_rust_project() {
    local name="$1"
    
    if command -v cargo &> /dev/null; then
        cargo new "$name"
        echo "✓ Rust project '$name' created with Cargo"
    else
        mkdir -p "$name/src"
        cd "$name"
        
        cat > Cargo.toml << EOF
[package]
name = "$name"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF
        
        cat > src/main.rs << EOF
fn main() {
    println!("Hello, world!");
}
EOF
        
        echo "# $name" > README.md
        echo "✓ Rust project '$name' created (install Rust for full functionality)"
    fi
}

create_web_project() {
    local name="$1"
    mkdir -p "$name"/{css,js,assets}
    cd "$name"
    
    cat > index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$name</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <h1>Welcome to $name</h1>
    <script src="js/main.js"></script>
</body>
</html>
EOF
    
    cat > css/style.css << EOF
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: Arial, sans-serif;
    line-height: 1.6;
    color: #333;
}

h1 {
    text-align: center;
    margin-top: 2rem;
}
EOF
    
    echo 'console.log("$name loaded");' > js/main.js
    echo "# $name" > README.md
    
    echo "✓ Web project '$name' created"
}

if [[ $# -lt 2 ]]; then
    show_help
    exit 1
fi

project_type="$1"
project_name="$2"

case "$project_type" in
    node|js)
        create_node_project "$project_name"
        ;;
    python|py)
        create_python_project "$project_name"
        ;;
    go)
        create_go_project "$project_name"
        ;;
    rust|rs)
        create_rust_project "$project_name"
        ;;
    web)
        create_web_project "$project_name"
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo "Unknown project type: $project_type"
        show_help
        exit 1
        ;;
esac