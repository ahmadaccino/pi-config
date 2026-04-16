# Pi Config

My personal pi coding agent configuration. Install everything with one command.

## Quick Install

```bash
pi install git:github.com/ahmadaccino/pi-config
```

Or with a specific version/branch:

```bash
pi install git:github.com/ahmadaccino/pi-config@main
```

## What's Included

### Skills

On-demand capability packages that enhance the agent:

- **agent-browser** - Browser automation for web scraping, form filling, testing
- **emil-design-eng** - Emil Kowalski's UI polish and design philosophy
- **emilkowal-animations** - Animation best practices for React/CSS/Framer Motion
- **figma-implement-design** - Translate Figma designs to code with visual fidelity
- **find-skills** - Discover and install new skills from the community
- **freedom-privacy** - Reference for Freedom privacy proxy architecture
- **skill-creator** - Create, modify, and benchmark skills

### MCP Servers

Model Context Protocol servers for extended capabilities:

- **figma** - Figma integration for design-to-code workflows

### Prompt Templates

*(Add your custom prompts to `prompts/` directory)*

## One-Command Setup

After installing this package, your pi agent will have access to all skills and MCP servers automatically.

To update to the latest version:

```bash
pi update
```

## Manual Installation

If you prefer to install individual components:

```bash
# Install just this package
pi install git:github.com/YOUR_USERNAME/pi-config

# List what's installed
pi list

# Configure what's enabled
pi config
```

## Development

To modify this configuration:

1. Fork this repo
2. Make your changes
3. Push and install from your fork:
   ```bash
   pi install git:github.com/ahmadaccino/pi-config
   ```

## Structure

```
pi-config/
├── package.json          # Package manifest with pi configuration
├── skills/               # Skill packages (SKILL.md files)
│   ├── agent-browser/
│   ├── emil-design-eng/
│   ├── emilkowal-animations/
│   ├── figma-implement-design/
│   ├── find-skills/
│   ├── freedom-privacy/
│   └── skill-creator/
├── prompts/              # Prompt templates (.md files)
└── README.md
```

## Adding New Skills

1. Create a new folder in `skills/`
2. Add a `SKILL.md` file with frontmatter
3. Push changes
4. Run `pi update` on any machine with this package installed

## Customization

This config is designed to be forked and modified. Make it your own!

- Add skills for your tech stack
- Add prompts for common workflows
- Add MCP servers for your tools
- Share with your team
