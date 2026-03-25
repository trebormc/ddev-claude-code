#!/bin/bash

# Set up agents, skills, and config from synced Claude Code volume
if [ -d "/agents-claude" ]; then
  mkdir -p /var/www/html/.claude

  # Symlink agents to .claude/agents/
  [ -d "/agents-claude/agent" ] && ln -sfn /agents-claude/agent /var/www/html/.claude/agents

  # Symlink skills to .claude/skills/ (both Claude Code and OpenCode discover this path)
  [ -d "/agents-claude/skills" ] && ln -sfn /agents-claude/skills /var/www/html/.claude/skills

  # Symlink rules to .claude/rules/
  [ -d "/agents-claude/rules" ] && ln -sfn /agents-claude/rules /var/www/html/.claude/rules

  # Copy CLAUDE.md to project root if not already present
  if [ ! -f "/var/www/html/CLAUDE.md" ] && [ -f "/agents-claude/CLAUDE.md" ]; then
    cp /agents-claude/CLAUDE.md /var/www/html/CLAUDE.md 2>/dev/null || true
  fi
fi

exec "$@"
