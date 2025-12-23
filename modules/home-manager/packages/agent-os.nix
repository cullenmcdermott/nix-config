{ pkgs, ... }:

# Agent OS wrapper scripts that point to $HOME/agent-os
# The actual Agent OS source is installed via home.file in claude-code.nix
pkgs.symlinkJoin {
  name = "agent-os";
  paths = [
    (pkgs.writeShellScriptBin "aos-project-install" ''
      exec "$HOME/agent-os/scripts/project-install.sh" "$@"
    '')
    (pkgs.writeShellScriptBin "aos-project-update" ''
      exec "$HOME/agent-os/scripts/project-update.sh" "$@"
    '')
    (pkgs.writeShellScriptBin "aos-create-profile" ''
      exec "$HOME/agent-os/scripts/create-profile.sh" "$@"
    '')
  ];
  meta = with pkgs.lib; {
    description = "Agent OS - Transforms AI coding agents from confused interns into productive developers";
    homepage = "https://github.com/buildermethods/agent-os";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
