#!/usr/bin/env bash

set -e  # Exit on any error

echo "🔄 Starting nixup process..."

# Change to the system config directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
cd "$SYSTEM_CONFIG_DIR"

echo "📍 Working in: $SYSTEM_CONFIG_DIR"

# Step 1: Update flake inputs
echo "📦 Updating flake inputs..."
nix flake update --accept-flake-config

# Step 2: Build and switch system configuration  
echo "🏗️  Building and switching system configuration..."

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
    # Linux with Home Manager only (distrobox setup)
    echo "   🏠 Detected Home Manager setup - using home-manager"
    home-manager switch --flake .#
else
    echo "   ⚠️  Could not detect system type or rebuild command"
    echo "   💡 You may need to manually run the appropriate rebuild command:"
    echo "      - macOS: sudo darwin-rebuild switch --flake .#"
    echo "      - NixOS: sudo nixos-rebuild switch --flake .#"  
    echo "      - Home Manager: home-manager switch --flake .#"
    exit 1
fi

echo "✅ nixup completed successfully!"
echo "🎉 System updated with latest packages and dependencies"