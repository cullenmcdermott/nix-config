#!/bin/bash
# Distrobox + Nix Setup Script for Bazzite
# Uses Ubuntu 24.04 LTS with deterministic Nix installer

set -euo pipefail

echo "🚀 Setting up Ubuntu-based Distrobox with Nix..."

# Check dependencies
if ! command -v distrobox &> /dev/null; then
    echo "❌ Distrobox not found. Please install distrobox first."
    exit 1
fi

USERNAME="$(whoami)"
USER_HOME="$HOME"
FLAKE_REPO="github:cullenmcdermott/nix-config"
CONTAINER_NAME="nix-dev"

echo "👤 User: $USERNAME"
echo "🏠 Home: $USER_HOME"
echo "📦 Flake: $FLAKE_REPO"

# Check if container already exists
if distrobox list | grep -q "$CONTAINER_NAME"; then
    echo "📦 Container '$CONTAINER_NAME' already exists. Entering..."
    exec distrobox enter "$CONTAINER_NAME"
fi

# Create Ubuntu-based container
echo "📦 Creating Ubuntu 24.04 container..."
SHELL=/bin/zsh distrobox create \
    --name "$CONTAINER_NAME" \
    --image ubuntu:24.04 \
    --home "$USER_HOME"

echo "🔧 Setting up Nix environment..."

# Create setup script inside container
distrobox enter "$CONTAINER_NAME" -- bash -c "
cat > /tmp/setup-nix.sh << 'SETUP_EOF'
#!/bin/bash
set -euo pipefail

echo '📦 Installing essential packages...'
sudo apt-get update
sudo apt-get install -y curl ca-certificates git zsh sudo xz-utils

echo '🔧 Installing Nix (single-user mode)...'
curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh -s -- --no-daemon

echo '🔄 Sourcing Nix environment...'
. ~/.nix-profile/etc/profile.d/nix.sh
export PATH=\"\$HOME/.nix-profile/bin:\$PATH\"

echo '📁 Setting up Nix configuration...'
# The system-config directory should already be mounted from the host
if [ ! -d /home/$USERNAME/src/system-config ]; then
    echo 'ERROR: /home/$USERNAME/src/system-config not found!'
    echo 'Make sure you have the system-config repo at ~/src/system-config on the host'
    exit 1
fi

echo '⚙️  Configuring Nix...'
mkdir -p /home/$USERNAME/.config/nix
cat > /home/$USERNAME/.config/nix/nix.conf << 'NIX_EOF'
experimental-features = nix-command flakes
use-xdg-base-directories = true
substituters = https://cache.nixos.org/ https://cache.flox.dev https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
NIX_EOF

# Also set environment variables for single-user mode
export NIX_REMOTE=""

echo '🏠 Setting up home-manager...'
nix run home-manager/release-25.05 -- init --switch /home/$USERNAME/src/system-config#$USERNAME@distrobox

echo '🐚 Setting zsh as default shell...'
sudo chsh -s \$(which zsh) $USERNAME

# Add Nix to shell profiles
echo '. ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
touch ~/.zshrc
chmod 644 ~/.zshrc
echo '. ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.zshrc

echo '🎉 Setup complete!'
SETUP_EOF

chmod +x /tmp/setup-nix.sh
/tmp/setup-nix.sh
"

echo "✅ Container '$CONTAINER_NAME' created and configured successfully!"
echo "🚀 Entering container..."

# Enter the container 
exec distrobox enter "$CONTAINER_NAME"
