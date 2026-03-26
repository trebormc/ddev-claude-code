#!/bin/bash

# =============================================================================
# Claude Code DDEV Entrypoint
# =============================================================================
# Runs before the main command on every container start.
# Generates .mcp.json with Playwright MCP connection for this DDEV project.
#
# Agents, skills, rules, and CLAUDE.md are mounted directly via Docker
# volume subpaths in docker-compose — no symlinks or copies needed.
#
# Config hierarchy (Claude Code in DDEV):
#   ~/.ddev/claude-code/settings.json       → user-level (shared, all projects)
#   <project>/.claude/settings.local.json   → project-level (per Drupal project)
#   <project>/.mcp.json                     → MCP servers (generated per project)
# =============================================================================

# --- Register Playwright MCP in project .mcp.json ---

if [ -n "$PLAYWRIGHT_MCP_URL" ]; then
  MCP_FILE="/var/www/html/.mcp.json"

  # Always regenerate — the URL is container-specific
  jq -n --arg url "$PLAYWRIGHT_MCP_URL" \
    '{"mcpServers": {"playwright": {"type": "http", "url": $url}}}' \
    > "$MCP_FILE"
fi

exec "$@"
