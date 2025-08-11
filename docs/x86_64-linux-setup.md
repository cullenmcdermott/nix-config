# Setting up system-config on x86_64-linux

This document provides instructions for setting up this Nix configuration on an x86_64-linux machine for the first time.

## Prerequisites

1. **Nix with flakes enabled**
2. **Git access** to this repository
3. **GitHub Personal Access Token** (for API rate limiting)

## Initial Setup Steps

### 1. Clone the repository
```bash
git clone <repository-url> ~/src/system-config
cd ~/src/system-config
```

### 2. Set up GitHub token for Nix
Create Nix config directory and add your GitHub token:
```bash
mkdir -p ~/.config/nix
echo "access-tokens = github.com=ghp_your_token_here" >> ~/.config/nix/nix.conf
```

Optionally, also add it to your `~/.env` file for other tools:
```bash
echo "GITHUB_TOKEN=ghp_your_token_here" >> ~/.env
```

### 3. Generate platform-specific lock files

The MCP servers require platform-specific lock files for reproducible builds. You'll need to generate the x86_64-linux versions:

#### For kagimcp:
```bash
cd ~/src/system-config/modules/home-manager/mcp-servers/kagimcp
nix run ~/src/system-config#kagimcp.lock --system x86_64-linux
```

#### For serena:
```bash
cd ~/src/system-config/modules/home-manager/mcp-servers/serena  
nix run ~/src/system-config#serena.lock --system x86_64-linux
```

This will create:
- `lock.x86_64-linux.json` files in each MCP server directory
- Exact dependency versions pinned for reproducible builds

### 4. Commit the new lock files
```bash
git add modules/home-manager/mcp-servers/*/lock.x86_64-linux.json
git commit -m "Add x86_64-linux lock files for MCP servers"
```

### 5. Apply the configuration

#### For NixOS:
```bash
sudo nixos-rebuild switch --flake ~/src/system-config/.#
```

#### For Nix + Home Manager on Linux:
```bash
nix run home-manager -- switch --flake ~/src/system-config/.#
```

## Ongoing Updates

After initial setup, you can use the `nixup` command to update everything:

```bash
# This will work after the initial setup
nixup
```

The `nixup` command will:
1. Update flake inputs  
2. Refresh pyproject.toml files from upstream
3. Regenerate lock files for your current platform
4. Rebuild the system

## Troubleshooting

### GitHub Rate Limiting
If you encounter rate limiting errors, ensure your GitHub token has these scopes:
- `repo` (Full control of private repositories)
- `read:org` (Read org and team membership)  
- `workflow` (Update GitHub Action workflows)

### Missing Lock Files
If you get errors about missing lock files, you forgot to generate them in step 3. Go back and run the lock generation commands.

### Cross-Platform Compatibility
This configuration supports both aarch64-darwin (ARM Mac) and x86_64-linux. The lock files are platform-specific and committed to the repository for reproducibility across machines.