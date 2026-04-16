# Pi Config

My personal pi coding agent configuration. Install everything with one command.

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/ahmadaccino/pi-config/main/install.sh | bash
```

Or manually:

```bash
pi install npm:pi-mcp-adapter
```

## What's Included

### Packages

- **pi-mcp-adapter** - MCP server support for pi

### MCP Servers

Configure in `~/.pi/agent/mcp.json`:

```json
{
  "mcpServers": {
    "figma": {
      "url": "http://127.0.0.1:3845/mcp",
      "excludeTools": [
        "get_code_connect_map",
        "add_code_connect_map",
        "get_code_connect_suggestions",
        "send_code_connect_mappings",
        "get_figjam",
        "create_design_system_rules"
      ]
    }
  }
}
```

## Skills

Install separately from original sources:

```bash
# Browser automation
pi install git:github.com/vercel-labs/agent-browser

# UI/Animation best practices
pi install git:github.com/emilkowalski/skill
pi install git:github.com/pproenca/dot-skills

# Figma design implementation
pi install git:github.com/figma/mcp-server-guide

# Skill discovery and creation
pi install git:github.com/anthropics/skills
```

## Settings

My default settings (`~/.pi/agent/settings.json`):

```json
{
  "defaultThinkingLevel": "minimal",
  "defaultProvider": "amazon-bedrock",
  "defaultModel": "zai.glm-5"
}
```

## Update

```bash
pi update
```
