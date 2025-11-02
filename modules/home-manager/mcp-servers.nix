{ pkgs, inputs, lib, ... }:

# All MCP packages are now built from embedded sources in lib/mcp-packages.nix
# This provides a clean interface to access them
inputs.self.packages.${pkgs.stdenv.hostPlatform.system}