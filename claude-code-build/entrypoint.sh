#!/bin/bash

# =============================================================================
# Claude Code DDEV Entrypoint
# =============================================================================
# Runs before the main command on every container start.
# Sets up: agents, skills, rules, CLAUDE.md, and Playwright MCP registration.
#
# Config hierarchy (Claude Code):
#   ~/.claude/settings.json          → user-level (shared dir, all projects)
#   <project>/.claude/settings.local.json → project-level (per Drupal project)
# =============================================================================

CLAUDE_HOME="/home/claude/.claude"
PROJECT_CLAUDE="/var/www/html/.claude"

# --- 1. Set up agents, skills, rules from synced volume ---

if [ -d "/agents-claude" ]; then
  mkdir -p "$PROJECT_CLAUDE"

  # Symlink agents to project .claude/agents/
  [ -d "/agents-claude/agent" ] && ln -sfn /agents-claude/agent "$PROJECT_CLAUDE/agents"

  # Symlink skills to project .claude/skills/
  [ -d "/agents-claude/skills" ] && ln -sfn /agents-claude/skills "$PROJECT_CLAUDE/skills"

  # Symlink rules to project .claude/rules/
  [ -d "/agents-claude/rules" ] && ln -sfn /agents-claude/rules "$PROJECT_CLAUDE/rules"

  # Copy CLAUDE.md to project root if not already present
  if [ ! -f "/var/www/html/CLAUDE.md" ] && [ -f "/agents-claude/CLAUDE.md" ]; then
    cp /agents-claude/CLAUDE.md /var/www/html/CLAUDE.md 2>/dev/null || true
  fi
fi

# --- 2. Register Playwright MCP in user-level settings (shared across projects) ---

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
