#!/bin/bash
# Distrobox + NixOS Setup Script for Bazzite
# Uses official nixos/nix Docker image as base

set -e

echo "🚀 Setting up Distrobox with official NixOS image..."

# Check if distrobox is available
if ! command -v distrobox &> /dev/null; then
    echo "❌ Distrobox not found. Please install distrobox first."
    exit 1
fi

USERNAME="$(whoami)"
USER_HOME="$HOME"

echo "👤 User: $USERNAME"
echo "🏠 Home: $USER_HOME"

# Create NixOS-based container with your flake pre-configured
echo "📦 Creating NixOS container with your system config..."
distrobox create \
    --name nixos-dev \
    --image nixos/nix:latest \
    --home "$USER_HOME" \
    --init-hooks "
        # Configure Nix settings for flakes and substituters
        mkdir -p /home/$USERNAME/.config/nix
        cat > /home/$USERNAME/.config/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
substituters = https://cache.nixos.org/ https://cache.flox.dev https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
extra-substituters = https://cache.nixos.org https://cache.flox.dev https://nix-community.cachix.org
extra-trusted-public-keys = flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
extra-platforms = x86_64-linux aarch64-linux
extra-system-features = big-parallel kvm
EOF

        # Install Home Manager
        nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz home-manager
        nix-channel --update
        nix-shell '<home-manager>' -A install

        # Set up shell environment
        echo 'source ~/.nix-profile/etc/profile.d/hm-session-vars.sh' >> /home/$USERNAME/.bashrc
        echo 'source ~/.nix-profile/etc/profile.d/hm-session-vars.sh' >> /home/$USERNAME/.zshrc || true

        # Create helpful aliases for container environment
        cat >> /home/$USERNAME/.bashrc << 'EOF'

# Container-specific aliases
alias nixswitch='home-manager switch --flake ~/src/system-config/.#cullen@distrobox'
alias nixup='pushd ~/src/system-config; nix flake update; nixswitch; popd'
alias host-cmd='distrobox-host-exec'
alias host-flatpak='distrobox-host-exec flatpak'
EOF

        echo '🎉 NixOS container configured successfully!'
        echo 'Your system-config flake is ready to use with home-manager'
    " \
    --volume "$USER_HOME/src:$USER_HOME/src" \
    --additional-packages "git"

echo "✅ NixOS distrobox container created successfully!"
echo ""
echo "🔧 Next steps:"
echo "1. Ensure your system-config is at: ~/src/system-config"
echo "2. Enter container: distrobox enter nixos-dev"
echo "3. Apply your config: nixswitch"
echo ""
echo "🚪 Enter container:"
echo "  distrobox enter nixos-dev"