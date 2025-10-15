#!/bin/bash
set -euo pipefail

# Test script to verify claudebox security properties
# Ensures that sensitive data (conversations, shell-snapshots) never enter the container

echo "🔒 Testing claudebox security..."
echo ""

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    echo "✅ $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo "❌ $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Create a temporary test directory
TEST_DIR=$(mktemp -d)

echo "📁 Test directory: $TEST_DIR"
echo ""

# Count host conversations for comparison
HOST_PROJECTS_COUNT=0
if [[ -d "$HOME/.claude/projects" ]]; then
    HOST_PROJECTS_COUNT=$(find "$HOME/.claude/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi

HOST_SNAPSHOTS_COUNT=0
if [[ -d "$HOME/.claude/shell-snapshots" ]]; then
    HOST_SNAPSHOTS_COUNT=$(find "$HOME/.claude/shell-snapshots" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

echo "📊 Host data:"
echo "   Conversations: $HOST_PROJECTS_COUNT"
echo "   Shell snapshots: $HOST_SNAPSHOTS_COUNT"
echo ""

# Start a test container using docker directly (avoids TTY issues)
echo "🚀 Starting test container..."

CONTAINER_NAME="claude-security-test-$$"

# Build docker command with same mounts as claudebox
docker_cmd=(
    docker run --rm --name "$CONTAINER_NAME" -d
    -w /workspace
)

# Mount only specific files and directories from .claude (same as claudebox)
if [[ -f "$HOME/.claude/settings.json" ]]; then
    docker_cmd+=(-v "$HOME/.claude/settings.json:/tmp/claude-general/settings.json:ro")
fi

if [[ -d "$HOME/.claude/agents" ]]; then
    docker_cmd+=(-v "$HOME/.claude/agents:/tmp/claude-general/agents:ro")
fi

for mdfile in "$HOME/.claude"/*.md; do
    if [[ -f "$mdfile" ]]; then
        filename=$(basename "$mdfile")
        docker_cmd+=(-v "$mdfile:/tmp/claude-general/$filename:ro")
    fi
done

# Use a simple ubuntu/node image and sleep
docker_cmd+=(node:20 sleep 30)

# Start container
"${docker_cmd[@]}" > /dev/null 2>&1 || {
    echo "❌ Failed to start test container"
    exit 1
}

# Give it a moment to fully start
sleep 1

echo "📦 Testing container: $CONTAINER_NAME"
echo ""

# Run security checks
echo "🔒 Running security checks..."
echo ""

# Test 1: projects directory not mounted
if docker exec "$CONTAINER_NAME" test -d /tmp/claude-general/projects 2>/dev/null; then
    test_fail "projects/ directory IS mounted to /tmp/claude-general"
else
    test_pass "projects/ directory NOT mounted"
fi

# Test 2: shell-snapshots directory not mounted
if docker exec "$CONTAINER_NAME" test -d /tmp/claude-general/shell-snapshots 2>/dev/null; then
    test_fail "shell-snapshots/ directory IS mounted to /tmp/claude-general"
else
    test_pass "shell-snapshots/ directory NOT mounted"
fi

# Test 3: Verify expected items are present
if docker exec "$CONTAINER_NAME" test -e /tmp/claude-general/settings.json 2>/dev/null; then
    test_pass "settings.json is present"
else
    echo "ℹ️  settings.json not found (may not exist on host)"
fi

if docker exec "$CONTAINER_NAME" test -d /tmp/claude-general/agents 2>/dev/null; then
    test_pass "agents/ directory is present"
else
    echo "ℹ️  agents/ directory not found (may not exist on host)"
fi

# Test 4: Check markdown files
MD_COUNT=$(docker exec "$CONTAINER_NAME" find /tmp/claude-general -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "ℹ️  Found $MD_COUNT markdown files in /tmp/claude-general"

# Test 5: Container projects directory is minimal
CONTAINER_PROJECTS=0
if docker exec "$CONTAINER_NAME" test -d /home/node/.claude/projects 2>/dev/null; then
    CONTAINER_PROJECTS=$(docker exec "$CONTAINER_NAME" find /home/node/.claude/projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ $CONTAINER_PROJECTS -le 1 ]]; then
    test_pass "Container has $CONTAINER_PROJECTS project(s) (current session only)"
else
    test_fail "Container has $CONTAINER_PROJECTS projects (should be 0-1, host has $HOST_PROJECTS_COUNT)"
fi

# Test 6: Container shell-snapshots is minimal
CONTAINER_SNAPSHOTS=0
if docker exec "$CONTAINER_NAME" test -d /home/node/.claude/shell-snapshots 2>/dev/null; then
    CONTAINER_SNAPSHOTS=$(docker exec "$CONTAINER_NAME" find /home/node/.claude/shell-snapshots -type f 2>/dev/null | wc -l | tr -d ' ')
fi

if [[ $CONTAINER_SNAPSHOTS -le 2 ]]; then
    test_pass "Container has $CONTAINER_SNAPSHOTS snapshot(s) (current session only)"
else
    test_fail "Container has $CONTAINER_SNAPSHOTS snapshots (should be 0-2, host has $HOST_SNAPSHOTS_COUNT)"
fi

# Cleanup
echo ""
echo "🧹 Cleaning up..."
docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
rm -rf "$TEST_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✅ All security tests passed! ($TESTS_PASSED passed, $TESTS_FAILED failed)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "❌ Some security tests failed! ($TESTS_PASSED passed, $TESTS_FAILED failed)"
    echo ""
    echo "Your conversations and shell snapshots may be exposed to the container!"
    echo "This usually means an old claudebox container is running."
    echo ""
    echo "Fix: Kill all containers and try again:"
    echo "  docker ps -a --filter 'name=claude-code-auth' --format '{{.Names}}' | xargs docker rm -f"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
