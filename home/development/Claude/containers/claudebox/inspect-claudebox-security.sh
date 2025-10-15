#!/bin/bash
set -euo pipefail

# Inspect a running claudebox container for security properties
# Usage: inspect-claudebox-security [container-name]

echo "🔍 Claudebox Security Inspector"
echo "================================"
echo ""

# Find container
if [[ $# -gt 0 ]]; then
    CONTAINER_NAME="$1"
else
    CONTAINER_NAME=$(docker ps --filter "name=claude-code-auth" --format "{{.Names}}" | head -1)
    if [[ -z "$CONTAINER_NAME" ]]; then
        echo "❌ No running claudebox containers found"
        echo ""
        echo "Start a claudebox container first, then run this script:"
        echo "  cd ~/code/some-project && claudebox"
        echo "  # In another terminal:"
        echo "  inspect-claudebox-security"
        exit 1
    fi
fi

echo "📦 Inspecting container: $CONTAINER_NAME"
echo ""

# Get host stats
HOST_PROJECTS=0
if [[ -d "$HOME/.claude/projects" ]]; then
    HOST_PROJECTS=$(find "$HOME/.claude/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi

HOST_SNAPSHOTS=0
if [[ -d "$HOME/.claude/shell-snapshots" ]]; then
    HOST_SNAPSHOTS=$(find "$HOME/.claude/shell-snapshots" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

echo "📊 Host has:"
echo "   - $HOST_PROJECTS conversation directories"
echo "   - $HOST_SNAPSHOTS shell snapshots"
echo ""

# Check /tmp/claude-general
echo "🔒 Checking /tmp/claude-general (mounted from host):"
echo ""

if docker exec "$CONTAINER_NAME" test -d /tmp/claude-general/projects 2>/dev/null; then
    echo "   ❌ FAIL: projects/ directory IS mounted"
else
    echo "   ✅ PASS: projects/ directory NOT mounted"
fi

if docker exec "$CONTAINER_NAME" test -d /tmp/claude-general/shell-snapshots 2>/dev/null; then
    echo "   ❌ FAIL: shell-snapshots/ directory IS mounted"
else
    echo "   ✅ PASS: shell-snapshots/ directory NOT mounted"
fi

MOUNTED_COUNT=$(docker exec "$CONTAINER_NAME" find /tmp/claude-general -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
echo "   ℹ️  Total items in /tmp/claude-general: $MOUNTED_COUNT"

echo ""
echo "   Expected items:"
for item in settings.json agents CLAUDE.md core-principles.md debugging.md lisp.md research-journal.md runpod.md style.md; do
    if docker exec "$CONTAINER_NAME" test -e "/tmp/claude-general/$item" 2>/dev/null; then
        echo "   ✅ $item"
    else
        echo "   ⚠️  $item (not found - may not exist on host)"
    fi
done

echo ""
echo "🏠 Checking /home/node/.claude (container's working directory):"
echo ""

CONTAINER_PROJECTS=0
if docker exec "$CONTAINER_NAME" test -d /home/node/.claude/projects 2>/dev/null; then
    CONTAINER_PROJECTS=$(docker exec "$CONTAINER_NAME" find /home/node/.claude/projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi

CONTAINER_SNAPSHOTS=0
if docker exec "$CONTAINER_NAME" test -d /home/node/.claude/shell-snapshots 2>/dev/null; then
    CONTAINER_SNAPSHOTS=$(docker exec "$CONTAINER_NAME" find /home/node/.claude/shell-snapshots -type f 2>/dev/null | wc -l | tr -d ' ')
fi

echo "   Container has:"
echo "   - $CONTAINER_PROJECTS conversation directories (should be 0-1)"
echo "   - $CONTAINER_SNAPSHOTS shell snapshots (should be 0-1)"
echo ""

# Verdict
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ISSUES=0

if docker exec "$CONTAINER_NAME" test -d /tmp/claude-general/projects 2>/dev/null; then
    ISSUES=$((ISSUES + 1))
fi

if docker exec "$CONTAINER_NAME" test -d /tmp/claude-general/shell-snapshots 2>/dev/null; then
    ISSUES=$((ISSUES + 1))
fi

if [[ $CONTAINER_PROJECTS -gt 1 ]]; then
    echo "⚠️  Container has $CONTAINER_PROJECTS projects (expected 0-1 for current session)"
    ISSUES=$((ISSUES + 1))
fi

if [[ $CONTAINER_SNAPSHOTS -gt 2 ]]; then
    echo "⚠️  Container has $CONTAINER_SNAPSHOTS snapshots (expected 0-2 for current session)"
    ISSUES=$((ISSUES + 1))
fi

if [[ $ISSUES -eq 0 ]]; then
    echo "✅ Security: PASSED - No sensitive host data exposed to container"
else
    echo "❌ Security: FAILED - $ISSUES issue(s) found"
    echo ""
    echo "This container may have been started with an old version of claudebox."
    echo "Kill all containers and start fresh:"
    echo "  docker ps -a --filter 'name=claude-code-auth' --format '{{.Names}}' | xargs docker rm -f"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
