#!/bin/bash
# Distrobox + Nix setup for Bazzite (or any host with distrobox).
# Creates an Ubuntu 24.04 container, installs Nix, and activates this flake's
# portable home-manager configuration.
#
# Prerequisite: this repo must be checked out at ~/src/system-config on the host
# (it is bind-mounted into the container via --home "$HOME").

set -euo pipefail

if ! command -v distrobox &>/dev/null; then
  echo "distrobox not found. Please install distrobox first." >&2
  exit 1
fi

USERNAME="$(whoami)"
USER_HOME="$HOME"
CONTAINER_NAME="nix-dev"
ARCH="$(uname -m)" # x86_64 or aarch64
HM_CONFIG="${USERNAME}@${ARCH}-linux"
CONFIG_REPO="$USER_HOME/src/system-config"

echo "User:      $USERNAME"
echo "Home:      $USER_HOME"
echo "Container: $CONTAINER_NAME"
echo "HM config: $HM_CONFIG"

if distrobox list | grep -q "$CONTAINER_NAME"; then
  echo "Container '$CONTAINER_NAME' already exists. Entering..."
  exec distrobox enter "$CONTAINER_NAME"
fi

echo "Creating Ubuntu 24.04 container..."
SHELL=/bin/zsh distrobox create \
  --name "$CONTAINER_NAME" \
  --image ubuntu:24.04 \
  --home "$USER_HOME"

echo "Configuring Nix and home-manager inside the container..."
distrobox enter "$CONTAINER_NAME" -- bash -c "
cat > /tmp/setup-nix.sh << 'SETUP_EOF'
#!/bin/bash
set -euo pipefail

echo 'Installing essential packages...'
sudo apt-get update
sudo apt-get install -y curl ca-certificates git zsh sudo xz-utils

echo 'Installing Nix (single-user mode)...'
curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh -s -- --no-daemon

echo 'Sourcing Nix environment...'
. ~/.nix-profile/etc/profile.d/nix.sh
export PATH=\"\$HOME/.nix-profile/bin:\$PATH\"

if [ ! -d \"$CONFIG_REPO\" ]; then
  echo \"ERROR: $CONFIG_REPO not found. Check out system-config there on the host first.\" >&2
  exit 1
fi

echo 'Configuring Nix...'
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << 'NIX_EOF'
experimental-features = nix-command flakes
use-xdg-base-directories = true
substituters = https://cache.nixos.org/ https://cache.flox.dev https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
NIX_EOF

echo 'Activating home-manager configuration ($HM_CONFIG)...'
nix run home-manager -- switch -b backup --flake \"$CONFIG_REPO#$HM_CONFIG\"

echo 'Setting zsh as default shell...'
# Use the distro zsh: chsh only accepts shells listed in /etc/shells, and the
# Nix-profile zsh that \$(which zsh) resolves to is not listed there.
sudo chsh -s /usr/bin/zsh \"$USERNAME\"

# Only bash needs bootstrapping: it is not managed by home-manager, so the Nix
# profile has to be sourced explicitly. zsh gets the Nix environment from the
# generated ~/.config/zsh/.zshenv and SSH_ASKPASS/GIT_ASKPASS from
# home.sessionVariables — never append to those, home-manager rewrites them on
# every switch (and its zshrc lives in ~/.config/zsh, not ~/.zshrc).
if ! grep -qF 'profile.d/nix.sh' ~/.bashrc 2>/dev/null; then
  echo '. ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc
fi

echo 'Setup complete.'
SETUP_EOF

chmod +x /tmp/setup-nix.sh
/tmp/setup-nix.sh
"

echo "Container '$CONTAINER_NAME' created and configured. Entering..."
exec distrobox enter "$CONTAINER_NAME"
