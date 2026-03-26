#!/bin/bash

# =============================================================================
# Claude Code DDEV Entrypoint
# =============================================================================
# Runs before the main command on every container start.
# Registers Playwright MCP in user-level settings if not already configured.
#
# Agents, skills, rules, and CLAUDE.md are mounted directly via Docker
# volume subpaths in docker-compose — no symlinks or copies needed.
#
# Config hierarchy (Claude Code in DDEV):
#   ~/.ddev/claude-code/settings.json       → user-level (shared, all projects)
#   <project>/.claude/settings.local.json   → project-level (per Drupal project)
# =============================================================================

CLAUDE_HOME="/home/claude/.claude"

# --- Register Playwright MCP in user-level settings (shared across projects) ---

if [ -n "$PLAYWRIGHT_MCP_URL" ] && [ -d "$CLAUDE_HOME" ]; then
  SETTINGS_FILE="$CLAUDE_HOME/settings.json"

  if [ -f "$SETTINGS_FILE" ]; then
    # Only add mcpServers if not already configured
    if ! jq -e '.mcpServers.playwright' "$SETTINGS_FILE" > /dev/null 2>&1; then
      jq --arg url "$PLAYWRIGHT_MCP_URL" \
        '.mcpServers.playwright = {"type": "url", "url": $url}' \
        "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" \
        && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    fi
  else
    # Create settings with permissions and MCP config
    jq -n --arg url "$PLAYWRIGHT_MCP_URL" \
      '{"permissions": {"defaultMode": "bypassPermissions"}, "mcpServers": {"playwright": {"type": "url", "url": $url}}}' \
      > "$SETTINGS_FILE"
  fi
fi

exec "$@"
