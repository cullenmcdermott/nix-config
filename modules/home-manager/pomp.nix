{ config, lib, pkgs, ... }:

let
  cfg = config.programs.pomp;
  homeDir = config.home.homeDirectory;

  omp = pkgs.callPackage ./packages/omp.nix { };
  ompVersion = omp.version;

  # Directories on the host
  configDir = "${config.xdg.configHome}/omp";
  stateDir = "${homeDir}/.local/share/pomp/state/omp";
  stagingDir = "${homeDir}/.cache/pomp/staging/omp";

  # VM user home (Lima convention: /home/<username>.linux on macOS hosts)
  vmHome = "/home/${config.home.username}.linux";
  vmAgentDir = "${vmHome}/.config/omp/agent";
  vmStateMount = "/pomp-state";

  # --- Lima template ---
  limaTemplate = pkgs.writeText "pomp-vm.yaml" ''
    vmType: vz
    cpus: 4
    memory: 8GiB
    disk: 50GiB

    images:
      - location: "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-arm64.img"
        arch: aarch64
        digest: "sha256:0cc0a529a52109b52bf697a0d90bdd0f252e7ad91b3a67f70879d56d1f64e240"
      - location: "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img"
        arch: x86_64
        digest: "sha256:7cbfa215a3774c46c6dc29b457f4e9667acda85fc04c7971e1e592b5056e7573"

    mounts:
      - location: "${homeDir}/git"
        mountPoint: "${homeDir}/git"
        writable: true
      - location: "${stateDir}"
        mountPoint: "${vmStateMount}"
        writable: true

    provision:
      - mode: system
        script: |
          #!/bin/bash
          set -euo pipefail

          # --- omp binary ---
          ARCH=$(uname -m)
          case "$ARCH" in
            aarch64) ARCH_SUFFIX="arm64" ;;
            x86_64)  ARCH_SUFFIX="x64" ;;
            *)       echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
          esac
          OMP_VERSION="${ompVersion}"
          curl -fsSL "https://github.com/can1357/oh-my-pi/releases/download/v''${OMP_VERSION}/omp-linux-''${ARCH_SUFFIX}" \
            -o /usr/local/bin/omp
          chmod +x /usr/local/bin/omp

          # --- sshd: allow unix socket forwarding to rebind ---
          grep -q 'StreamLocalBindUnlink' /etc/ssh/sshd_config || \
            echo 'StreamLocalBindUnlink yes' >> /etc/ssh/sshd_config
          systemctl restart ssh

          # --- Network egress: internet yes, LAN no, outbound SSH no ---
          apt-get update -qq
          apt-get install -y iptables

          GW=$(ip route | awk '/default/ {print $3; exit}')

          # Allow gateway (NAT + DNS) before blocking RFC1918
          iptables  -A OUTPUT -d "$GW" -j ACCEPT
          ip6tables -A OUTPUT -o lo -j ACCEPT

          # Block RFC1918, link-local, IPv6 ULA
          iptables  -A OUTPUT -d 10.0.0.0/8    -j DROP
          iptables  -A OUTPUT -d 172.16.0.0/12  -j DROP
          iptables  -A OUTPUT -d 192.168.0.0/16 -j DROP
          iptables  -A OUTPUT -d 169.254.0.0/16 -j DROP
          ip6tables -A OUTPUT -d fc00::/7       -j DROP

          # Block outbound SSH (prevent lateral movement)
          iptables  -A OUTPUT -p tcp --dport 22 -j DROP

          # Persist rules across reboots
          mkdir -p /etc/iptables
          iptables-save  > /etc/iptables/rules.v4
          ip6tables-save > /etc/iptables/rules.v6

          # Restore on boot via networkd-dispatcher
          mkdir -p /etc/networkd-dispatcher/routable.d
          cat > /etc/networkd-dispatcher/routable.d/50-iptables-restore <<'RESTORE'
          #!/bin/bash
          iptables-restore  < /etc/iptables/rules.v4
          ip6tables-restore < /etc/iptables/rules.v6
          RESTORE
          chmod +x /etc/networkd-dispatcher/routable.d/50-iptables-restore

    ssh: {}
  '';

  # --- Bridge handler ---
  # Invoked by socat for each connection. Reads NDJSON from stdin, validates
  # the per-session token, dispatches open_url / secret requests.
  bridgeHandler = pkgs.writeShellScript "pomp-bridge-handler" ''
    set -euo pipefail
    JQ="${pkgs.jq}/bin/jq"

    while IFS= read -r line; do
      token=$("$JQ" -r '.token // empty' <<< "$line")
      if [ "$token" != "$POMP_BRIDGE_TOKEN" ]; then
        printf '{"ok":false,"error":"invalid token"}\n'
        continue
      fi

      msg_type=$("$JQ" -r '.type' <<< "$line")
      case "$msg_type" in
        open_url)
          url=$("$JQ" -r '.url' <<< "$line")
          case "$url" in
            http://*|https://*) open "$url" 2>/dev/null; printf '{"ok":true}\n' ;;
            *) printf '{"ok":false,"error":"blocked non-http scheme"}\n' ;;
          esac
          ;;
        secret)
          ref=$("$JQ" -r '.ref' <<< "$line")
          case "$ref" in
            op://*)
              if value=$(op read "$ref" 2>/dev/null); then
                printf '{"ok":true,"value":%s}\n' "$("$JQ" -Rs . <<< "$value")"
              else
                printf '{"ok":false,"error":"failed to read secret"}\n'
              fi
              ;;
            *) printf '{"ok":false,"error":"invalid ref format (must start with op://)"}\n' ;;
          esac
          ;;
        *)
          printf '{"ok":false,"error":"unknown type: %s"}\n' "$msg_type"
          ;;
      esac
    done
  '';

  # --- Main wrapper script ---
  # writeShellScriptBin (not writeShellApplication) so PATH is inherited —
  # limactl (Homebrew) and op (1Password) are not in the Nix store.
  pompWrapper = pkgs.writeShellScriptBin "pomp" ''
    set -euo pipefail

    # Nix store paths for deterministic tooling
    JQ="${pkgs.jq}/bin/jq"
    SOCAT="${pkgs.socat}/bin/socat"
    FLOCK="${pkgs.flock}/bin/flock"

    # Constants baked in at Nix build time
    VM_NAME="pomp-vm"
    LIMA_TEMPLATE="${limaTemplate}"
    BRIDGE_HANDLER="${bridgeHandler}"
    OMP_VERSION="${ompVersion}"
    HOST_HOME="${homeDir}"
    CONFIG_DIR="${configDir}"
    STATE_DIR="${stateDir}"
    STAGING_DIR="${stagingDir}"
    VM_HOME="${vmHome}"
    VM_AGENT_DIR="${vmAgentDir}"
    VM_STATE_MOUNT="${vmStateMount}"
    LOCK_FILE="''${TMPDIR:-/tmp}/pomp.lock"
    BRIDGE_SOCK="''${TMPDIR:-/tmp}/pomp-bridge-$$.sock"
    VM_BRIDGE_SOCK="/tmp/pomp-bridge.sock"

    ${builtins.readFile ./pomp/wrapper.sh}
  '';

in {
  options.programs.pomp = {
    enable = lib.mkEnableOption "pomp agent sandbox wrapper for omp";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pompWrapper ];

    # Ensure host directories exist at activation time
    home.activation.pompDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${stateDir}"
      run mkdir -p "${stagingDir}"
    '';
  };
}
