#!/usr/bin/env bash

set -e  # Exit on any error

# Source environment variables if ~/.env exists
[[ -f ~/.env ]] && source ~/.env

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔄 Starting nixup process..."
echo "📍 Working in: $SYSTEM_CONFIG_DIR"

# Debug: Check if GITHUB_TOKEN is available
if [[ -n "$GITHUB_TOKEN" ]]; then
    echo "🔑 GitHub token loaded (${#GITHUB_TOKEN} characters)"
else
    echo "⚠️  No GITHUB_TOKEN found - you may hit rate limits"
fi

# Step 1: Update flake inputs
echo "📦 Updating flake inputs..."
cd "$SYSTEM_CONFIG_DIR"
nix flake update --accept-flake-config

# Step 2: Update pyproject.toml files from updated inputs
echo "📝 Checking if pyproject.toml updates are needed..."

# For now, skip this step due to GitHub rate limiting issues
# The pyproject.toml files should be current from previous successful runs
if [ -f "modules/home-manager/mcp-servers/kagimcp/pyproject.toml" ] && [ -f "modules/home-manager/mcp-servers/serena/pyproject.toml" ]; then
    echo "   ✅ pyproject.toml files already exist, proceeding with current versions"
    echo "   💡 To force update: manually run 'nix build --no-link --print-out-paths github:kagisearch/kagimcp' and copy pyproject.toml"
else
    echo "   ⚠️  pyproject.toml files missing - you may need to copy them manually"
fi

# Step 3: Generate lock files for current platform only
echo "🔒 Generating MCP server lock files for current platform..."

# Detect current platform
CURRENT_SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem' 2>/dev/null || echo "unknown")
echo "   📋 Detected platform: $CURRENT_SYSTEM"

# kagimcp locks
echo "   🔐 Generating kagimcp lock for $CURRENT_SYSTEM..."
cd modules/home-manager/mcp-servers/kagimcp
if nix run "$SYSTEM_CONFIG_DIR#kagimcp.lock" --system "$CURRENT_SYSTEM"; then
    echo "   ✅ kagimcp lock generated successfully"
else
    echo "   ❌ Failed to generate kagimcp lock"
    exit 1
fi

# serena locks  
echo "   🔐 Generating serena lock for $CURRENT_SYSTEM..."
cd ../serena
if nix run "$SYSTEM_CONFIG_DIR#serena.lock" --system "$CURRENT_SYSTEM"; then
    echo "   ✅ serena lock generated successfully"
else
    echo "   ❌ Failed to generate serena lock"
    exit 1
fi

# Step 4: Build system
echo "🏗️  Building system configuration..."
cd "$SYSTEM_CONFIG_DIR"

# Detect the system type and use appropriate rebuild command
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS with nix-darwin
    echo "   🍎 Detected macOS - using darwin-rebuild"
    sudo darwin-rebuild switch --flake .#
elif [[ -f /etc/nixos/configuration.nix ]] || [[ -d /etc/nixos ]]; then
    # NixOS system
    echo "   🐧 Detected NixOS - using nixos-rebuild"
    sudo nixos-rebuild switch --flake .#
elif command -v home-manager >/dev/null 2>&1; then
    # Linux with Home Manager only
    echo "   🏠 Detected Home Manager setup - using home-manager"
    home-manager switch --flake .#
else
    echo "   ⚠️  Could not detect system type or rebuild command"
    echo "   💡 You may need to manually run the appropriate rebuild command:"
    echo "      - macOS: sudo darwin-rebuild switch --flake .#"
    echo "      - NixOS: sudo nixos-rebuild switch --flake .#"
    echo "      - Home Manager: home-manager switch --flake .#"
    echo "   📚 See docs/x86_64-linux-setup.md for more details"
    exit 1
fi

echo "✅ nixup completed successfully!"
echo "🎉 System updated with latest MCP servers and dependencies"