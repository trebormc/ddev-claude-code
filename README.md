[![tests](https://github.com/trebormc/ddev-claude-code/actions/workflows/tests.yml/badge.svg)](https://github.com/trebormc/ddev-claude-code/actions/workflows/tests.yml)

# ddev-claude-code

A DDEV add-on that runs [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's official CLI) in a dedicated container for AI-powered Drupal development.

## Quick Start

```bash
# 1. Install the add-on
ddev add-on get trebormc/ddev-claude-code

# 2. Restart DDEV
ddev restart

# 3. Authenticate (choose one)
ddev claude-code claude login          # OAuth (recommended for subscribers)
# OR set API key in .ddev/.env.claude-code

# 4. Launch Claude Code
ddev claude-code
```

## Prerequisites

- [DDEV](https://ddev.readthedocs.io/) >= v1.23.5
- An Anthropic API key or OAuth session

## Installation

```bash
ddev add-on get trebormc/ddev-claude-code
ddev restart
```

This automatically installs [ddev-playwright-mcp](https://github.com/trebormc/ddev-playwright-mcp) (browser automation) and [ddev-beads](https://github.com/trebormc/ddev-beads) (task tracking) as dependencies.

## Authentication

Credentials are stored in a shared directory on the host (`~/.ddev/claude-code/` by default), so you only need to authenticate **once** — all your DDEV projects share the same session automatically.

**Option A: OAuth login (recommended for Claude Pro/Team/Enterprise subscribers)**

```bash
ddev claude-code claude login
```

This opens a browser for OAuth authentication. The credentials are saved in the shared config directory and persist across `ddev restart`, new projects, and machine reboots.

**Option B: API key**

```bash
ddev dotenv set .ddev/.env.claude-code --anthropic-api-key=sk-ant-your-key-here
ddev restart
```

## Configuration

After installation, environment variables are in `.ddev/.env.claude-code`:

```bash
# Shared config directory — credentials, settings, and session data.
# Shared across ALL DDEV projects. Change only if you need a custom location.
HOST_CLAUDE_CONFIG_DIR=${HOME}/.ddev/claude-code

# API key (alternative to OAuth login)
#ANTHROPIC_API_KEY=sk-ant-...

# Timezone
TZ=UTC
```

> **Note:** `HOST_CLAUDE_CONFIG_DIR` must point to an existing directory. The installer creates `~/.ddev/claude-code/` automatically. If you change this value, make sure the directory exists before running `ddev restart`.

### Permissions

The installer creates a default `settings.json` with `bypassPermissions` mode — all permission prompts are disabled since Claude Code runs inside an isolated DDEV container. This is the equivalent of OpenCode's `{"*":"allow"}`.

To use a more restrictive mode, edit `~/.ddev/claude-code/settings.json`:

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

Available modes: `bypassPermissions` (default, no prompts), `auto` (smart classifier), `acceptEdits` (auto-approve edits only), `default` (prompt for everything).

Since it lives in the shared config directory, permission changes apply to all DDEV projects.

## Architecture

```
┌─────────────────────────────────────────────────┐
│              DDEV Docker Network                 │
│                                                  │
│  ┌──────────────┐  docker exec  ┌────────────┐  │
│  │  Claude Code │──────────────>│    Web     │  │
│  │  Container   │               │   (PHP)    │  │
│  │              │               │  (Drupal)  │  │
│  └──────┬───────┘               └────────────┘  │
│         │ MCP HTTP                               │
│         v                                        │
│  ┌──────────────┐  ┌──────────────┐              │
│  │  Playwright  │  │    Beads     │              │
│  │     MCP      │  │  (bd tasks)  │              │
│  └──────────────┘  └──────────────┘              │
└─────────────────────────────────────────────────┘
```

Claude Code communicates with the web container via `docker exec` (through the mounted Docker socket), giving it full CLI access to drush, composer, phpunit, phpstan, and any other tool in the web container.

Playwright MCP is accessed over HTTP for browser automation and visual testing.

## Commands

| Command | Description |
|---------|-------------|
| `ddev claude-code` | Start Claude Code interactive session |
| `ddev claude-code shell` | Open bash shell in the container |
| `ddev claude-code claude <args>` | Run Claude Code with specific arguments |

## CLAUDE.md Integration

Claude Code uses `CLAUDE.md` files for project-specific instructions. Place a `CLAUDE.md` in your Drupal project root with guidelines for the AI. It is automatically picked up by Claude Code.

Example `CLAUDE.md` for a Drupal project:

```markdown
# Project Instructions

## Environment
- This is a DDEV project with containers: claude-code (you), web (PHP/Drupal), playwright-mcp, beads
- Run PHP commands via: docker exec $WEB_CONTAINER <command>
- Playwright MCP at: http://playwright-mcp:8931/mcp

## Drupal Standards
- Drupal coding standards (2-space indent, strict_types)
- declare(strict_types=1) in all PHP files
- Dependency injection only -- never use \Drupal::service() in classes
- Run code quality checks:
  - docker exec $WEB_CONTAINER ./vendor/bin/phpcs --standard=Drupal,DrupalPractice web/modules/custom
  - docker exec $WEB_CONTAINER ./vendor/bin/phpstan analyse web/modules/custom --level=8
  - docker exec $WEB_CONTAINER ./vendor/bin/phpunit web/modules/custom

## Workflow
- Always run drush cr after changing services or routing
- Test changes with phpunit before marking work complete
- Use Playwright MCP to verify visual changes in the browser
```

For a comprehensive set of Drupal development instructions, see [drupal-ai-agents](https://github.com/trebormc/drupal-ai-agents) -- while it is designed for OpenCode, its rules and agent prompts are an excellent reference for writing your `CLAUDE.md`.

## Desktop Notifications

Claude Code can send desktop notifications when sessions finish. Add a stop hook to `.claude/settings.json`:

```json
{
  "hooks": {
    "stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "curl -s -X POST http://host.docker.internal:5454/notify -H 'Content-Type: application/json' -d '{\"title\":\"Claude Code\",\"message\":\"Session finished\"}'"
          }
        ]
      }
    ]
  }
}
```

Then start the notification bridge on your host:

```bash
# From the DDEV AI workspace
./scripts/start-notify-bridge.sh
```

See the [DDEV AI workspace](https://github.com/trebormc/ddev-ai-workspace) for full notification setup details.

## Autonomous Execution

For autonomous task execution (overnight runs), see the separate [ddev-ralph](https://github.com/trebormc/ddev-ralph) add-on.

## Related

- [drupal-ai-agents](https://github.com/trebormc/drupal-ai-agents) -- 13 agents, 14 skills, and Drupal rules (OpenCode format, useful as CLAUDE.md reference)
- [ddev-beads](https://github.com/trebormc/ddev-beads) -- Beads task tracker (auto-installed)
- [ddev-playwright-mcp](https://github.com/trebormc/ddev-playwright-mcp) -- Playwright browser automation (auto-installed)
- [ddev-opencode](https://github.com/trebormc/ddev-opencode) -- Alternative: OpenCode AI for DDEV
- [ddev-ralph](https://github.com/trebormc/ddev-ralph) -- Autonomous task runner

## Disclaimer

This project is not affiliated with Anthropic, OpenCode, Beads, Playwright, Microsoft, or DDEV. AI-generated code may contain errors -- always review changes before deploying to production. See [menetray.com](https://menetray.com) for more information and [DruScan](https://druscan.com) for Drupal auditing tools.

## License

Apache-2.0. See [LICENSE](LICENSE).
