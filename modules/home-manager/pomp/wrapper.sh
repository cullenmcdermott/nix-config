#!/hint/bash
# Not executed directly; sourced into the Nix-generated wrapper.
# Variables available from Nix preamble:
#   VM_NAME, LIMA_TEMPLATE, BRIDGE_HANDLER, OMP_VERSION, HOST_HOME,
#   CONFIG_DIR, STATE_DIR, STAGING_DIR, VM_HOME, VM_AGENT_DIR,
#   VM_STATE_MOUNT, LOCK_FILE, BRIDGE_SOCK, VM_BRIDGE_SOCK,
#   JQ, SOCAT, FLOCK

BRIDGE_PID=""

cleanup() {
  if [ -n "$BRIDGE_PID" ]; then
    kill "$BRIDGE_PID" 2>/dev/null || true
    wait "$BRIDGE_PID" 2>/dev/null || true
  fi
  rm -f "$BRIDGE_SOCK"
}
trap cleanup EXIT

log() { printf 'pomp: %s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }

# ── VM lifecycle helpers ─────────────────────────────────────────────────────

vm_status() {
  local status
  status=$(limactl list --json 2>/dev/null \
    | "$JQ" -r "select(.name == \"$VM_NAME\") | .status" 2>/dev/null)
  printf '%s' "${status:-NotFound}"
}

vm_ensure_running() {
  local status
  status=$(vm_status)

  case "$status" in
    Running) ;;
    Stopped)
      log "starting VM..."
      limactl start "$VM_NAME" 2>&1 | while IFS= read -r line; do log "  $line"; done
      ;;
    NotFound)
      log "creating VM (first run)..."
      limactl start --name="$VM_NAME" --tty=false "$LIMA_TEMPLATE" 2>&1 \
        | while IFS= read -r line; do log "  $line"; done
      ;;
    *)
      die "VM in unexpected state: $status"
      ;;
  esac
}

vm_preflight() {
  # Use SSH directly — limactl shell cds to the host cwd which may not exist in the VM.
  local ssh_config="$HOME/.lima/$VM_NAME/ssh.config"
  local ssh_opts="-F $ssh_config -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=4"
  # shellcheck disable=SC2086
  if ! timeout 5 ssh $ssh_opts "lima-$VM_NAME" true 2>/dev/null; then
    log "VM unresponsive, bouncing..."
    limactl stop "$VM_NAME" 2>/dev/null || true
    limactl start "$VM_NAME" 2>&1 | while IFS= read -r line; do log "  $line"; done
    # shellcheck disable=SC2086
    if ! timeout 10 ssh $ssh_opts "lima-$VM_NAME" true 2>/dev/null; then
      die "VM failed to recover after bounce"
    fi
  fi
}

# ── Config staging ───────────────────────────────────────────────────────────

stage_config() {
  log "staging config..."
  rm -rf "$STAGING_DIR"
  mkdir -p "$STAGING_DIR"

  # Resolve symlinks (nix store → real files)
  cp -RL "$CONFIG_DIR/agent/" "$STAGING_DIR/agent/" 2>/dev/null || true

  # Remove state paths from staging (they live on the writable mount)
  ( cd "$STAGING_DIR/agent" 2>/dev/null && \
    rm -f agent.db agent.db-shm agent.db-wal \
          history.db history.db-shm history.db-wal \
          models.db models.db-shm models.db-wal 2>/dev/null || true
    rm -rf sessions terminal-sessions 2>/dev/null || true
  )
}

sync_config_to_vm() {
  log "syncing config to VM..."
  limactl shell --workdir=/ "$VM_NAME" -- bash -c "rm -rf '$VM_AGENT_DIR' && mkdir -p '$VM_AGENT_DIR'"
  limactl copy --recursive "$STAGING_DIR/agent/" "$VM_NAME:$VM_AGENT_DIR/"
}

setup_state_symlinks() {
  log "linking state..."
  # shellcheck disable=SC2016  # $f and $d are intentionally literals for the remote shell
  limactl shell --workdir=/ "$VM_NAME" -- bash -c '
    for f in agent.db agent.db-shm agent.db-wal \
             history.db history.db-shm history.db-wal \
             models.db models.db-shm models.db-wal; do
      ln -sf "'"$VM_STATE_MOUNT"'/$f" "'"$VM_AGENT_DIR"'/$f" 2>/dev/null || true
    done
    for d in sessions terminal-sessions; do
      mkdir -p "'"$VM_STATE_MOUNT"'/$d"
      ln -sfn "'"$VM_STATE_MOUNT"'/$d" "'"$VM_AGENT_DIR"'/$d" 2>/dev/null || true
    done
  '
}

# ── Agent version check ──────────────────────────────────────────────────────

ensure_agent_version() {
  local vm_ver
  vm_ver=$(limactl shell --workdir=/ "$VM_NAME" -- omp --version 2>/dev/null | tr -d '[:space:]' || echo "none")
  if [ "$vm_ver" != "$OMP_VERSION" ]; then
    log "updating omp in VM ($vm_ver → $OMP_VERSION)..."
    local arch_raw arch_suffix
    arch_raw=$(limactl shell --workdir=/ "$VM_NAME" -- uname -m)
    case "$arch_raw" in
      aarch64) arch_suffix="arm64" ;;
      x86_64)  arch_suffix="x64" ;;
      *)        die "Unsupported VM arch: $arch_raw" ;;
    esac
    limactl shell --workdir=/ "$VM_NAME" -- sudo bash -c "
      curl -fsSL 'https://github.com/can1357/oh-my-pi/releases/download/v${OMP_VERSION}/omp-linux-${arch_suffix}' \
        -o /usr/local/bin/omp && chmod +x /usr/local/bin/omp
    "
  fi
}

# ── Host bridge ──────────────────────────────────────────────────────────────

start_bridge() {
  POMP_BRIDGE_TOKEN=$(openssl rand -hex 32)
  export POMP_BRIDGE_TOKEN

  rm -f "$BRIDGE_SOCK"
  "$SOCAT" UNIX-LISTEN:"$BRIDGE_SOCK",fork EXEC:"$BRIDGE_HANDLER" &
  BRIDGE_PID=$!

  # Wait briefly for socket to appear
  local i=0
  while [ ! -S "$BRIDGE_SOCK" ] && [ $i -lt 20 ]; do
    sleep 0.05
    i=$((i + 1))
  done
  [ -S "$BRIDGE_SOCK" ] || die "bridge socket did not appear"
}

# ── Env forwarding ───────────────────────────────────────────────────────────

build_env_args() {
  local env_args=""
  local var val
  for var in ANTHROPIC_API_KEY GITHUB_TOKEN GH_TOKEN; do
    val="${!var:-}"
    if [ -n "$val" ]; then
      env_args="$env_args $var='$val'"
    fi
  done
  # Bridge env vars (always set)
  env_args="$env_args POMP_BRIDGE_SOCK='$VM_BRIDGE_SOCK'"
  env_args="$env_args POMP_BRIDGE_TOKEN='$POMP_BRIDGE_TOKEN'"
  # Agent dir
  env_args="$env_args PI_CODING_AGENT_DIR='$VM_AGENT_DIR'"
  env_args="$env_args PI_CONFIG_DIR='${VM_HOME}/.config/omp'"
  env_args="$env_args PI_TELEMETRY=0"
  printf '%s' "$env_args"
}

# ── Launch ───────────────────────────────────────────────────────────────────

cmd_launch() {
  local agent="${1:-omp}"
  if [ "$agent" != "omp" ]; then
    die "only 'omp' profile is supported (got: $agent)"
  fi

  # Acquire startup lock — prevents two concurrent instances from racing on VM creation
  exec 9>"$LOCK_FILE"
  if ! "$FLOCK" -n 9; then
    log "another pomp is starting the VM, waiting..."
    "$FLOCK" 9
  fi

  vm_ensure_running
  vm_preflight

  # Release lock — VM is up, other instances can proceed
  "$FLOCK" -u 9

  stage_config
  sync_config_to_vm
  setup_state_symlinks
  ensure_agent_version
  start_bridge

  local env_args
  env_args=$(build_env_args)

  local ssh_config="$HOME/.lima/$VM_NAME/ssh.config"
  local work_dir="${PWD}"

  # Verify work_dir is under ~/git (the mounted tree); fall back to the mount root
  case "$work_dir" in
    "$HOST_HOME/git"*) ;;
    *) work_dir="$HOST_HOME/git" ;;
  esac

  log "launching omp..."
  # shellcheck disable=SC2086
  ssh -F "$ssh_config" \
    -A \
    -R "$VM_BRIDGE_SOCK:$BRIDGE_SOCK" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -t \
    "lima-$VM_NAME" \
    -- "cd '$work_dir' && env $env_args omp"
  exit $?
}

# ── Subcommands ──────────────────────────────────────────────────────────────

cmd_status() {
  local status
  status=$(vm_status)
  printf 'VM:       %s (%s)\n' "$VM_NAME" "$status"
  printf 'Template: %s\n' "$LIMA_TEMPLATE"
  printf 'State:    %s\n' "$STATE_DIR"
  printf 'Staging:  %s\n' "$STAGING_DIR"
  if [ "$status" = "Running" ]; then
    printf 'omp:      %s\n' "$(limactl shell --workdir=/ "$VM_NAME" -- omp --version 2>/dev/null || echo 'not installed')"
    printf 'Mounts:\n'
    limactl list --json 2>/dev/null \
      | "$JQ" -r "select(.name == \"$VM_NAME\") | .config.mounts[] | \"  \\(.location) → \\(.mountPoint) (writable: \\(.writable))\"" 2>/dev/null || true
  fi
}

cmd_shell() {
  vm_ensure_running
  vm_preflight
  local ssh_config="$HOME/.lima/$VM_NAME/ssh.config"
  ssh -F "$ssh_config" -A -t "lima-$VM_NAME"
}

cmd_init() {
  local status
  status=$(vm_status)
  if [ "$status" != "NotFound" ]; then
    log "VM already exists (status: $status). Use 'pomp destroy' first to recreate."
    return 1
  fi
  log "creating VM..."
  limactl start --name="$VM_NAME" --tty=false "$LIMA_TEMPLATE"
  log "VM created."
}

cmd_destroy() {
  local status
  status=$(vm_status)
  case "$status" in
    NotFound)
      log "VM does not exist."
      return 0
      ;;
    Running)
      log "stopping VM..."
      limactl stop "$VM_NAME"
      ;& # fall through
    *)
      log "deleting VM..."
      limactl delete "$VM_NAME"
      log "VM deleted. State in $STATE_DIR is preserved."
      ;;
  esac
}

# ── Main dispatch ────────────────────────────────────────────────────────────

case "${1:-}" in
  status)  cmd_status ;;
  shell)   cmd_shell ;;
  init)    cmd_init ;;
  destroy) cmd_destroy ;;
  -h|--help)
    printf 'Usage: pomp [command]\n\n'
    printf 'Commands:\n'
    printf '  pomp [<agent>]  Launch agent in VM (default: omp)\n'
    printf '  pomp shell      Login shell into VM\n'
    printf '  pomp status     Show VM state and config\n'
    printf '  pomp init       Create VM (if not exists)\n'
    printf '  pomp destroy    Stop and delete VM\n'
    ;;
  ""|omp) cmd_launch "${1:-omp}" ;;
  *)      cmd_launch "$1" ;;
esac
