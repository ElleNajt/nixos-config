#!/usr/bin/env bash
set -euo pipefail

# Build script for claudebox containers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔨 Building claudebox containers..."

# Build main container
echo "📦 Building main container: claude-code-devcontainer"
docker build -t claude-code-devcontainer -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"

# Build SSH agent container
echo "📦 Building SSH agent: claudebox-ssh-agent"
docker build -t claudebox-ssh-agent -f "$SCRIPT_DIR/proxies/ssh-agent/Dockerfile" "$SCRIPT_DIR/proxies/ssh-agent"

echo "✅ Build complete!"
echo ""
echo "Images built:"
docker images | grep -E "claude-code-devcontainer|claudebox-ssh-agent"
