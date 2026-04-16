#!/bin/bash
# Pi Configuration Setup Script
# Run this to match ahmadaccino's pi setup

set -e

echo "🚀 Installing pi packages..."

# Install MCP adapter
pi install npm:pi-mcp-adapter

echo "✅ Done! Pi configuration installed."
echo ""
echo "Installed packages:"
echo "  - pi-mcp-adapter (MCP server support)"
echo ""
echo "MCP servers are configured separately in ~/.pi/agent/mcp.json"
