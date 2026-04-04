# Work laptop overrides for Claude Code and other home-manager modules
#
# This module layers work-specific configuration on top of the base
# settings from modules/home-manager/default.nix.
#
# To enable, add this to your work system's extraHomeManagerModules in flake.nix:
#   extraHomeManagerModules = [ ./systems/work/claude-code.nix ];
#
# The Nix module system handles merging:
#   - Lists (permissions) concatenate and are deduplicated
#   - Attrsets (MCP servers, LSP servers, skills) merge by key
#   - Strings (claudeMd) concatenate with newlines
#   - Set a skill to null to disable it
{ lib, ... }:
{
  # Disable Zwift media controls on work laptop
  programs.zwift-media.enable = lib.mkForce false;

  programs.claude-code = {
    settings.env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };

    # Add work-specific MCP servers
    # mcpServers.internal-docs = {
    #   command = "mcp-server-internal-docs";
    #   args = [ "--endpoint" "https://docs.internal.corp" ];
    # };

    # Add work-specific permissions
    # settings.permissions.allow = [
    #   "Bash(kubectl:*)"
    #   "Bash(terraform:*)"
    # ];

    # Add work-specific CLAUDE.md content
    # claudeMd = lib.mkAfter ''
    #   ## Work Environment
    #   - Internal docs available via internal-docs MCP server
    #   - Use kubectl context "prod" for production clusters
    # '';

    # Disable specific skills by overriding with empty string
    # skills.home-assistant = lib.mkForce "";
    # skills.slack-gif-creator = lib.mkForce "";

    # Add work-specific skills
    # skills.internal-deploy.source = ./skills/internal-deploy;
  };
}
