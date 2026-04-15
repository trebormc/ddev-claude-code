#!/bin/bash
#ddev-generated

# =============================================================================
# Claude Code DDEV Entrypoint
# =============================================================================
# Runs before the main command on every container start.
#
# 1. Fixes Docker socket access (GID mismatch between host and container)
# 2. Generates .mcp.json with Playwright MCP connection
#
# Agents directories are mounted via volume subpaths in docker-compose.
# CLAUDE.md is copied from the volume in the entrypoint (file subpath
# mounts fail on empty volumes because Docker resolves them at creation time).
#
# Config hierarchy (Claude Code in DDEV):
#   ~/.ddev/claude-code/settings.json       → user-level (shared, all projects)
#   <project>/.claude/settings.local.json   → project-level (per Drupal project)
#   <project>/.mcp.json                     → MCP servers (generated per project)
# =============================================================================

# --- 0. Ensure HOME directory is writable ---
# When docker-compose overrides user UID/GID, /home/claude may be owned by
# the build-time UID (1000). Fix ownership so the runtime user can write there.
if [ -d "$HOME" ] && [ ! -w "$HOME" ]; then
  sudo chown -R "$(id -u):$(id -g)" "$HOME"
fi
# Ensure .claude directory exists for config and MCP client cache
mkdir -p "$HOME/.claude" 2>/dev/null || true

# --- 1. Copy CLAUDE.md from agents-sync volume ---
# Directories (agents, skills, rules) are mounted via volume subpaths in docker-compose.
# CLAUDE.md cannot use a file subpath mount (Docker fails on empty volumes), so we copy it.
if [ -f "/agents-data/CLAUDE.md" ]; then
  cp /agents-data/CLAUDE.md /var/www/html/CLAUDE.md
fi

# --- 2. Fix Docker socket access if needed ---
# On Linux, the socket GID may not match the container's docker group.
# On macOS/Windows Docker Desktop, the socket is already accessible — this is skipped.
if [ -z "$_DOCKER_GROUP_FIXED" ] && [ -S /var/run/docker.sock ] && ! docker info > /dev/null 2>&1; then
  SOCK_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "")
  if [ -n "$SOCK_GID" ] && [ "$SOCK_GID" != "0" ]; then
    sudo groupadd -g "$SOCK_GID" docker-host 2>/dev/null || true
    sudo usermod -aG docker-host "$(whoami)" 2>/dev/null || true
    export _DOCKER_GROUP_FIXED=1
    sg docker-host -c "export _DOCKER_GROUP_FIXED=1; $0 $*" && exit 0 || true
  fi
fi

# --- 2. Register Playwright MCP in project .mcp.json ---
if [ -n "$PLAYWRIGHT_MCP_URL" ]; then
  MCP_FILE="/var/www/html/.mcp.json"

  # Always regenerate — the URL is container-specific
  jq -n --arg url "$PLAYWRIGHT_MCP_URL" \
    '{"mcpServers": {"playwright": {"type": "http", "url": $url}}}' \
    > "$MCP_FILE"
fi

exec "$@"
