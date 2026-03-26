#!/bin/bash

# =============================================================================
# Claude Code DDEV Entrypoint
# =============================================================================
# Runs before the main command on every container start.
#
# 1. Fixes Docker socket access (GID mismatch between host and container)
# 2. Generates .mcp.json with Playwright MCP connection
#
# Agents, skills, rules, and CLAUDE.md are mounted directly via Docker
# volume subpaths in docker-compose — no symlinks or copies needed.
#
# Config hierarchy (Claude Code in DDEV):
#   ~/.ddev/claude-code/settings.json       → user-level (shared, all projects)
#   <project>/.claude/settings.local.json   → project-level (per Drupal project)
#   <project>/.mcp.json                     → MCP servers (generated per project)
# =============================================================================

# --- 1. Fix Docker socket access if needed ---
# On Linux, the socket GID may not match the container's docker group.
# On macOS/Windows Docker Desktop, the socket is already accessible — this is skipped.
if [ -z "$_DOCKER_GROUP_FIXED" ] && [ -S /var/run/docker.sock ] && ! docker info > /dev/null 2>&1; then
  SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
  if [ -n "$SOCK_GID" ] && [ "$SOCK_GID" != "0" ]; then
    sudo groupadd -g "$SOCK_GID" docker-host 2>/dev/null || true
    sudo usermod -aG docker-host "$(whoami)" 2>/dev/null || true
    export _DOCKER_GROUP_FIXED=1
    exec sg docker-host -c "$0 $*"
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
