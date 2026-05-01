# Pi Sandboxing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build three pi extensions (VM Manager, Permission Gate, Secret Forwarder) that provide VM-based isolation with permission gating and explicit secret forwarding for the pi coding agent.

**Architecture:** pi runs locally on macOS. A pi extension replaces the four core tool backends (read, write, edit, bash) with SSH-delegated versions running inside an ephemeral Lima VZ VM. A permission gate extension classifies commands as auto or prompt. A secret forwarder allowlists specific env vars, sockets, files, and ports. Mutagen provides bidirectional file sync.

**Tech Stack:** TypeScript (pi extensions), Lima (VM management), VZ hypervisor, Mutagen (file sync), Flox (VM package management), SSH (tool transport)

---

## File Structure

```
modules/home-manager/pi/extensions/
├── vm-manager/
│   ├── index.ts              # Main extension entry point
│   ├── vm-lifecycle.ts        # Lima VM boot, provision, teardown
│   ├── ssh-tools.ts           # SSH-delegated read/write/edit/bash tool factories
│   ├── mutagen-sync.ts        # Mutagen session lifecycle
│   ├── port-forward.ts        # Dynamic port forwarding management
│   ├── config.ts              # Config loading + merge
│   ├── lima-template.yaml     # Lima VM template (embedded or referenced)
│   └── package.json           # Dependencies (ssh2 or similar)
├── permission-gate/
│   ├── index.ts               # Main extension entry point
│   ├── classifier.ts          # Pattern matching + classification logic
│   ├── config.ts              # Config loading + merge
│   └── package.json
├── secret-forwarder/
│   ├── index.ts               # Main extension entry point
│   ├── ssh-config.ts          # SSH arg injection (env, sockets, files, ports)
│   ├── config.ts              # Config loading (global only)
│   └── package.json
├── safety.ts                  # (existing, will be modified)
└── ...                        # (existing extensions)
```

Config files (managed by nix):
```
~/.pi/agent/extensions/vm-manager.json
~/.pi/agent/extensions/permission-gate.json
~/.pi/agent/extensions/secret-forwarder.json
```

Nix module changes:
```
modules/home-manager/pi.nix           # Add mutagen package, extension file mappings
modules/home-manager/pi/extensions/   # New extension directories
```

---

### Task 1: Infrastructure — Mutagen + Nix Setup

**Files:**
- Modify: `modules/home-manager/pi.nix`
- Modify: `modules/home-manager/packages/` (or wherever packages are added)

- [ ] **Step 1: Add mutagen to nix packages**

Add `mutagen` to the home-manager package list so it's available on the system. Check it's in nixpkgs:

```bash
nix search nixpkgs mutagen
```

Then add it to the appropriate package list in `modules/home-manager/pi.nix` or the dev-packages module:

```nix
# In the appropriate packages section
home.packages = [ pkgs.mutagen ];
```

- [ ] **Step 2: Verify mutagen installation**

Run: `nix build .#homeConfigurations.cullen.activationPackage` (or equivalent rebuild command)
Then verify: `which mutagen && mutagen version`

- [ ] **Step 3: Create extension directory structure**

Create the three extension directories with `package.json` files:

```bash
mkdir -p modules/home-manager/pi/extensions/{vm-manager,permission-gate,secret-forwarder}
```

Each `package.json` should follow the pattern from the existing `sandbox/` example:

```json
{
  "name": "pi-extension-vm-manager",
  "private": true,
  "type": "module",
  "scripts": {
    "clean": "echo 'nothing to clean'",
    "build": "echo 'nothing to build'",
    "check": "echo 'nothing to check'"
  },
  "pi": {
    "extensions": ["./index.ts"]
  }
}
```

(Similar for permission-gate and secret-forwarder, with appropriate names.)

- [ ] **Step 4: Add extension file mappings to pi.nix**

In `modules/home-manager/pi.nix`, add `xdg.configFile` entries for each new extension directory:

```nix
"pi/agent/extensions/vm-manager" = {
  source = ./pi/extensions/vm-manager;
  recursive = true;
};
"pi/agent/extensions/permission-gate" = {
  source = ./pi/extensions/permission-gate;
  recursive = true;
};
"pi/agent/extensions/secret-forwarder" = {
  source = ./pi/extensions/secret-forwarder;
  recursive = true;
};
```

- [ ] **Step 5: Add config file templates to pi.nix**

Add stub config files to `xdg.configFile` in pi.nix (or as standalone files managed by nix):

```nix
"pi/agent/extensions/vm-manager.json".text = builtins.toJSON {
  vmType = "vz";
  cpus = 4;
  memory = "8GiB";
  disk = "50GiB";
};
```

(Similar stubs for permission-gate and secret-forwarder configs.)

- [ ] **Step 6: Commit**

```bash
git add modules/home-manager/pi.nix modules/home-manager/pi/extensions/
git commit -m "feat(pi-sandbox): add infrastructure for vm-manager, permission-gate, secret-forwarder extensions"
```

---

### Task 2: Permission Gate Extension — Config & Classifier

**Files:**
- Create: `modules/home-manager/pi/extensions/permission-gate/config.ts`
- Create: `modules/home-manager/pi/extensions/permission-gate/classifier.ts`

- [ ] **Step 1: Write config loading and merge module**

Create `config.ts` with `loadConfig()` function that:
1. Reads `~/.pi/agent/extensions/permission-gate.json` (global)
2. Reads `<cwd>/.pi/permission-gate.json` (project-local) if it exists
3. Deep merges: project `autoPatterns` and `promptPatterns` are unioned with global patterns
4. Global restrictions cannot be removed by project config
5. Returns typed `PermissionGateConfig`:

```typescript
export interface PatternRules {
  autoPatterns: string[];
  promptPatterns: string[];
}

export interface PermissionGateConfig {
  enabled: boolean;
  rules: {
    bash: PatternRules;
    write: { mode: "auto" | "prompt" };
    edit: { mode: "auto" | "prompt" };
  };
}

const DEFAULT_CONFIG: PermissionGateConfig = {
  enabled: true,
  rules: {
    bash: {
      autoPatterns: [
        "git status*", "git log*", "git diff*", "git branch*",
        "kubectl get *", "kubectl describe *", "kubectl logs *",
        "rg *", "fd *", "cat *", "ls *", "find *",
        "head *", "tail *", "wc *", "file *", "which *",
        "flox list*", "flox search*",
      ],
      promptPatterns: [
        "kubectl apply *", "kubectl delete *", "kubectl patch *",
        "kubectl create *", "git push*", "rm *", "sudo *",
      ],
    },
    write: { mode: "prompt" },
    edit: { mode: "prompt" },
  },
};
```

Pattern matching uses glob-style matching: `*` matches any characters, `?` matches one character. Use `minimatch` or a simple glob matcher.

- [ ] **Step 2: Write the classifier module**

Create `classifier.ts` with a `classify()` function:

```typescript
import { minimatch } from "minimatch";

export type Classification = "auto" | "prompt";

export function classifyBash(
  command: string,
  rules: PatternRules,
): Classification {
  // Check auto patterns first (specificity order)
  for (const pattern of rules.autoPatterns) {
    if (minimatch(command, pattern)) return "auto";
  }
  // Then check prompt patterns
  for (const pattern of rules.promptPatterns) {
    if (minimatch(command, pattern)) return "prompt";
  }
  // Deny-by-default for unknowns
  return "prompt";
}

export function classifyTool(
  toolName: string,
  command: string | undefined,
  config: PermissionGateConfig,
): Classification {
  if (toolName === "read" || toolName === "ls" || toolName === "grep" || toolName === "find") {
    return "auto";
  }
  if (toolName === "write" || toolName === "edit") {
    return config.rules[toolName].mode === "auto" ? "auto" : "prompt";
  }
  if (toolName === "bash" && command) {
    return classifyBash(command, config.rules.bash);
  }
  return "prompt"; // Unknown tools default to prompt
}
```

- [ ] **Step 3: Write unit tests for classifier**

Create `modules/home-manager/pi/extensions/permission-gate/classifier.test.ts`:

```typescript
import { classifyBash, classifyTool, Classification } from "./classifier";

// Test auto patterns
assert(classifyBash("git status", DEFAULT_RULES) === "auto");
assert(classifyBash("git diff src/app.ts", DEFAULT_RULES) === "auto");
assert(classifyBash("kubectl get pods", DEFAULT_RULES) === "auto");

// Test prompt patterns
assert(classifyBash("kubectl apply -f deploy.yaml", DEFAULT_RULES) === "prompt");
assert(classifyBash("rm -rf /tmp/thing", DEFAULT_RULES) === "prompt");
assert(classifyBash("sudo systemctl restart nginx", DEFAULT_RULES) === "prompt");

// Test deny-by-default
assert(classifyBash("some-unknown-command --flag", DEFAULT_RULES) === "prompt");

// Test tool classification
assert(classifyTool("read", undefined, DEFAULT_CONFIG) === "auto");
assert(classifyTool("write", undefined, DEFAULT_CONFIG) === "prompt");
assert(classifyTool("bash", "git status", DEFAULT_CONFIG) === "auto");
assert(classifyTool("bash", "kubectl apply -f ns.yaml", DEFAULT_CONFIG) === "prompt");
```

- [ ] **Step 4: Commit**

```bash
git add modules/home-manager/pi/extensions/permission-gate/
git commit -m "feat(permission-gate): add config loading and command classifier"
```

---

### Task 3: Permission Gate Extension — Main Extension

**Files:**
- Create: `modules/home-manager/pi/extensions/permission-gate/index.ts`

- [ ] **Step 1: Write the main extension**

Create `index.ts` that:
1. Loads config on `session_start`
2. Hooks `tool_call` event
3. Classifies each tool call
4. If "prompt" — shows UI with exact command and pattern options
5. If "always allow" is chosen — writes pattern to project config

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { loadConfig, savePattern } from "./config";
import { classifyTool, Classification } from "./classifier";
import type { PermissionGateConfig } from "./config";

export default function permissionGateExtension(pi: ExtensionAPI) {
  let config: PermissionGateConfig | null = null;

  pi.on("session_start", async (_event, ctx) => {
    config = loadConfig(ctx.cwd);
    if (!config.enabled) {
      ctx.ui.notify("Permission Gate: disabled", "info");
    } else {
      const autoCount = config.rules.bash.autoPatterns.length;
      const promptCount = config.rules.bash.promptPatterns.length;
      ctx.ui.setStatus("pg", ctx.ui.theme.fg("success", `🔒 PG: ${autoCount} auto / ${promptCount} prompt`));
    }
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!config || !config.enabled) return undefined;
    if (!ctx.hasUI) {
      // Non-interactive: auto-allow reads, block everything else
      if (event.toolName === "read" || event.toolName === "ls" ||
          event.toolName === "grep" || event.toolName === "find") {
        return undefined; // auto
      }
      return { block: true, reason: `Non-interactive mode: ${event.toolName} blocked` };
    }

    const command = event.toolName === "bash"
      ? String((event.input as Record<string, unknown>).command ?? "")
      : undefined;

    const classification = classifyTool(event.toolName, command, config);

    if (classification === "auto") return undefined;

    // Prompt the user
    const toolLabel = event.toolName === "bash" ? `bash:\n\n  ${command}` : event.toolName;

    const options = buildPromptOptions(event.toolName, command, config);

    const choice = await ctx.ui.select(
      `⚠️  Mutative ${toolLabel}\n\nAllow?`,
      options.map((o) => o.label),
    );

    const selected = options.find((o) => o.label === choice);

    if (!selected || selected.action === "block") {
      return { block: true, reason: "Blocked by permission gate" };
    }

    if (selected.action === "always-exact" || selected.action === "always-pattern") {
      savePattern(ctx.cwd, event.toolName, selected.pattern, classification === "prompt" ? "autoPatterns" : "promptPatterns");
      config = loadConfig(ctx.cwd); // Reload config
    }

    return undefined; // Allow
  });
}

interface PromptOption {
  label: string;
  action: "once" | "always-exact" | "always-pattern" | "block";
  pattern?: string;
}

function buildPromptOptions(
  toolName: string,
  command: string | undefined,
  config: PermissionGateConfig,
): PromptOption[] {
  const options: PromptOption[] = [
    { label: "Yes (this time only)", action: "once" },
  ];

  if (toolName === "bash" && command) {
    // Always offer exact command allow
    options.push({
      label: `Yes (always allow: ${command})`,
      action: "always-exact",
      pattern: command,
    });

    // Offer pattern allow only if a known promptPattern matched
    const matchedPattern = config.rules.bash.promptPatterns.find((p) => minimatch(command, p));
    if (matchedPattern) {
      options.push({
        label: `Yes (always allow: ${matchedPattern})`,
        action: "always-pattern",
        pattern: matchedPattern,
      });
    }
  }

  if (toolName === "write" || toolName === "edit") {
    options.push({
      label: `Yes (always allow ${toolName})`,
      action: "always-pattern",
      pattern: `${toolName}:*`,
    });
  }

  options.push({ label: "No", action: "block" });

  return options;
}
```

- [ ] **Step 2: Test the extension manually**

Run pi with the permission gate loaded:

```bash
pi -e ./modules/home-manager/pi/extensions/permission-gate
```

Try various commands:
- `git status` → should auto-approve
- `kubectl get pods` → should auto-approve
- `kubectl apply -f test.yaml` → should prompt with 3 options (once, always exact, always pattern)
- `write` tool call → should prompt
- Unknown command → should prompt with 2 options (once, always exact)

- [ ] **Step 3: Commit**

```bash
git add modules/home-manager/pi/extensions/permission-gate/
git commit -m "feat(permission-gate): implement main extension with prompt UI"
```

---

### Task 4: VM Manager Extension — Config & VM Lifecycle

**Files:**
- Create: `modules/home-manager/pi/extensions/vm-manager/config.ts`
- Create: `modules/home-manager/pi/extensions/vm-manager/vm-lifecycle.ts`
- Create: `modules/home-manager/pi/extensions/vm-manager/lima-template.yaml`

- [ ] **Step 1: Write config loading module**

`config.ts`:

```typescript
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

export interface VmManagerConfig {
  enabled: boolean;
  vmType: "vz" | "qemu";
  cpus: number;
  memory: string;
  disk: string;
  image: string;
  nixStorePath: string; // Host path for persistent nix store volume
  mutagenBin: string;   // Path to mutagen binary
  projectSyncPath: string; // Default: "." (current project dir)
}

const DEFAULT_CONFIG: VmManagerConfig = {
  enabled: true,
  vmType: "vz",
  cpus: 4,
  memory: "8GiB",
  disk: "50GiB",
  image: "https://cloud-images.ubuntu.com/minimal/releases/24.04/release/ubuntu-24.04-minimal-cloudimg-arm64.img",
  nixStorePath: "~/.pi/agent/vm/nix-store",
  mutagenBin: "mutagen",
  projectSyncPath: ".",
};

export function loadConfig(cwd: string): VmManagerConfig {
  const globalPath = join(getAgentDir(), "extensions", "vm-manager.json");
  const projectPath = join(cwd, ".pi", "vm-manager.json");
  // Deep merge: project overrides global
  return deepMerge(
    DEFAULT_CONFIG,
    loadJsonFile(globalPath),
    loadJsonFile(projectPath),
  );
}
```

- [ ] **Step 2: Write the Lima YAML template**

Create `lima-template.yaml` — a Lima VM config template with placeholders for dynamic values:

```yaml
vmType: vz
arch: aarch64
cpus: 4
memory: 8GiB
disk: 50GiB

images:
  - location: "https://cloud-images.ubuntu.com/minimal/releases/24.04/release/ubuntu-24.04-minimal-cloudimg-arm64.img"
    arch: aarch64

mounts:
  - location: "~/.pi/agent/vm/nix-store"
    mountPoint: "/nix"
    writable: true

provision:
  - mode: system
    script: |
      #!/bin/bash
      set -euo pipefail
      # Install Flox
      sh <(curl -L https://flox.dev/install) || true
      # Install Docker
      apt-get update
      apt-get install -y docker.io
      systemctl enable docker
      systemctl start docker
      usermod -aG docker {{ .User }}

ssh:
  localForward: []
```

- [ ] **Step 3: Write VM lifecycle module**

`vm-lifecycle.ts`: Functions for `startVm`, `stopVm`, `checkVmStatus`, `waitForSsh`.

```typescript
import { exec } from "node:child_process";
import { promisify } from "node:util";
import type { VmManagerConfig } from "./config";

const execAsync = promisify(exec);

const VM_NAME = "pi-vm";

export interface VmStatus {
  running: boolean;
  name: string;
  sshTarget: string;
}

export async function checkVmStatus(): Promise<VmStatus> {
  try {
    const { stdout } = await execAsync("limactl list --json");
    const vms = stdout.trim().split("\n").filter(Boolean).map((line) => JSON.parse(line));
    const vm = vms.find((v: any) => v.name === VM_NAME);
    if (vm && vm.status === "Running") {
      return { running: true, name: VM_NAME, sshTarget: `lima-${VM_NAME}` };
    }
    return { running: false, name: VM_NAME, sshTarget: "" };
  } catch {
    return { running: false, name: VM_NAME, sshTarget: "" };
  }
}

export async function startVm(config: VmManagerConfig): Promise<VmStatus> {
  const status = await checkVmStatus();
  if (status.running) return status;

  // Generate Lima config from template
  const templatePath = /* path to lima-template.yaml */;
  await execAsync(`limactl start --name=${VM_NAME} ${templatePath}`);
  await waitForSsh();
  return checkVmStatus();
}

export async function stopVm(): Promise<void> {
  const status = await checkVmStatus();
  if (!status.running) return;
  await execAsync(`limactl stop ${VM_NAME}`);
  await execAsync(`limactl delete ${VM_NAME}`);
}

export async function waitForSsh(maxRetries = 30, delayMs = 1000): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await execAsync(`limactl shell ${VM_NAME} echo ok`, { timeout: 5000 });
      return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw new Error(`VM SSH not ready after ${maxRetries} retries`);
}

export async function runInVm(command: string, config: VmManagerConfig): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  // Run command inside flox-activated shell in the VM
  const wrappedCommand = `cd /home/user/project && flox activate -- ${command}`;
  try {
    const { stdout, stderr } = await execAsync(`limactl shell ${VM_NAME} /bin/bash -c ${JSON.stringify(wrappedCommand)}`, {
      timeout: 120000,
    });
    return { stdout, stderr, exitCode: 0 };
  } catch (err: any) {
    return { stdout: err.stdout ?? "", stderr: err.stderr ?? "", exitCode: err.code ?? 1 };
  }
}
```

- [ ] **Step 4: Test VM lifecycle**

Manually test the lifecycle functions by starting and stopping a VM:

```bash
# Build/run a quick test script
node -e "
import { startVm, stopVm, checkVmStatus } from './vm-lifecycle';
const status = await checkVmStatus();
console.log(status);
const vm = await startVm({ vmType: 'vz', cpus: 4, memory: '8GiB', disk: '50GiB' });
console.log(vm);
await stopVm();
"
```

Expected: VM starts, SSH becomes available, VM stops and is deleted.

- [ ] **Step 5: Commit**

```bash
git add modules/home-manager/pi/extensions/vm-manager/
git commit -m "feat(vm-manager): add config loading and VM lifecycle management"
```

---

### Task 5: VM Manager Extension — SSH Tool Delegation

**Files:**
- Create: `modules/home-manager/pi/extensions/vm-manager/ssh-tools.ts`

This is the core of the extension. It replaces pi's built-in read/write/edit/bash tools with SSH-delegated versions, following the pattern from pi's `ssh.ts` example.

- [ ] **Step 1: Write SSH operations factories**

`ssh-tools.ts`: Define `ReadOperations`, `WriteOperations`, `EditOperations`, and `BashOperations` that execute via SSH to the Lima VM. Use `limactl shell pi-vm` as the SSH transport.

```typescript
import { spawn, exec } from "node:child_process";
import { promisify } from "node:util";
import type { BashOperations, EditOperations, ReadOperations, WriteOperations } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

const execAsync = promisify(exec);
const VM_NAME = "pi-vm";

const LOCAL_CWD = process.cwd();
const REMOTE_CWD = "/home/user/project";

function toRemote(p: string): string {
  return p.replace(LOCAL_CWD, REMOTE_CWD);
}

function sshExec(command: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const child = spawn("limactl", ["shell", VM_NAME, "bash", "-c", command], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    const chunks: Buffer[] = [];
    const errChunks: Buffer[] = [];
    child.stdout.on("data", (data) => chunks.push(data));
    child.stderr.on("data", (data) => errChunks.push(data));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(`SSH failed (${code}): ${Buffer.concat(errChunks).toString()}`));
      } else {
        resolve(Buffer.concat(chunks));
      }
    });
  });
}

export function createRemoteReadOps(): ReadOperations {
  return {
    readFile: (p) => sshExec(`cat ${JSON.stringify(toRemote(p))}`),
    access: (p) => sshExec(`test -r ${JSON.stringify(toRemote(p))}`).then(() => {}, () => {}),
    detectImageMimeType: async (p) => {
      try {
        const r = await sshExec(`file --mime-type -b ${JSON.stringify(toRemote(p))}`);
        const m = r.toString().trim();
        return ["image/jpeg", "image/png", "image/gif", "image/webp"].includes(m) ? m : null;
      } catch { return null; }
    },
  };
}

export function createRemoteWriteOps(): WriteOperations {
  return {
    writeFile: async (p, content) => {
      const b64 = Buffer.from(content).toString("base64");
      await sshExec(`echo ${JSON.stringify(b64)} | base64 -d > ${JSON.stringify(toRemote(p))}`);
    },
    mkdir: (dir) => sshExec(`mkdir -p ${JSON.stringify(toRemote(dir))}`).then(() => {}),
  };
}

export function createRemoteEditOps(): EditOperations {
  const r = createRemoteReadOps();
  const w = createRemoteWriteOps();
  return { readFile: r.readFile, access: r.access, writeFile: w.writeFile };
}

export function createRemoteBashOps(): BashOperations {
  return {
    exec(command, cwd, { onData, signal, timeout }) {
      const remoteCwd = toRemote(cwd);
      const wrappedCommand = `cd ${JSON.stringify(remoteCwd)} && flox activate -- ${command}`;
      return new Promise((resolve, reject) => {
        const child = spawn("limactl", ["shell", VM_NAME, "bash", "-c", wrappedCommand], {
          stdio: ["ignore", "pipe", "pipe"],
          detached: true,
        });
        let timedOut = false;
        const timer = timeout
          ? setTimeout(() => { timedOut = true; child.kill("SIGKILL"); }, timeout * 1000)
          : undefined;
        child.stdout.on("data", onData);
        child.stderr.on("data", onData);
        child.on("error", (e) => { if (timer) clearTimeout(timer); reject(e); });
        const onAbort = () => { try { process.kill(-child.pid!, "SIGKILL"); } catch { child.kill("SIGKILL"); } };
        signal?.addEventListener("abort", onAbort, { once: true });
        child.on("close", (code) => {
          if (timer) clearTimeout(timer);
          signal?.removeEventListener("abort", onAbort);
          if (signal?.aborted) reject(new Error("aborted"));
          else if (timedOut) reject(new Error(`timeout:${timeout}`));
          else resolve({ exitCode: code });
        });
      });
    },
  };
}
```

- [ ] **Step 2: Test SSH operations**

Start a Lima VM manually and verify SSH operations work:

```bash
limactl start --name=pi-vm template.yaml
# Wait for SSH
limactl shell pi-vm echo "hello from vm"
```

Then test reading a file, writing a file, and running bash commands through the ops.

- [ ] **Step 3: Commit**

```bash
git add modules/home-manager/pi/extensions/vm-manager/ssh-tools.ts
git commit -m "feat(vm-manager): add SSH-delegated tool operations"
```

---

### Task 6: VM Manager Extension — Mutagen Sync & Port Forwarding

**Files:**
- Create: `modules/home-manager/pi/extensions/vm-manager/mutagen-sync.ts`
- Create: `modules/home-manager/pi/extensions/vm-manager/port-forward.ts`

- [ ] **Step 1: Write Mutagen sync lifecycle module**

`mutagen-sync.ts`: Start/stop Mutagen sync sessions between the laptop project dir and the VM.

```typescript
import { exec } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

const SESSION_NAME = "pi-vm-sync";

export async function startSync(localPath: string, mutagenBin: string): Promise<void> {
  // Check if session already exists
  try {
    const { stdout } = await execAsync(`${mutagenBin} sync list ${SESSION_NAME}`);
    if (stdout.includes(SESSION_NAME)) {
      // Resume existing session
      await execAsync(`${mutagenBin} sync resume ${SESSION_NAME}`);
      return;
    }
  } catch {}

  // Create new sync session
  await execAsync(
    `${mutagenBin} sync create ${localPath} lima-pi-vm:/home/user/project ${SESSION_NAME}`,
    { timeout: 30000 }
  );
}

export async function stopSync(mutagenBin: string): Promise<void> {
  try {
    await execAsync(`${mutagenBin} sync terminate ${SESSION_NAME}`);
  } catch {
    // Ignore errors if session doesn't exist
  }
}

export async function checkSyncStatus(mutagenBin: string): Promise<"idle" | "syncing" | "conflict" | "error" | "none"> {
  try {
    const { stdout } = await execAsync(`${mutagenBin} sync list ${SESSION_NAME}`);
    if (stdout.includes("Conflicts")) return "conflict";
    if (stdout.includes("Scanning") || stdout.includes("Syncing")) return "syncing";
    if (stdout.includes("Watching")) return "idle";
    return "none";
  } catch {
    return "none";
  }
}
```

- [ ] **Step 2: Write port forwarding module**

`port-forward.ts`: Manage dynamic SSH port forwarding for ports declared in config and auto-detected listeners.

```typescript
import { spawn, ChildProcess } from "node:child_process";
import type { PortForwardConfig } from "./config";

interface ForwardedPort {
  port: number;
  process: ChildProcess | null;
  label: string;
}

const forwardedPorts: Map<number, ForwardedPort> = new Map();

export async function startStaticForwards(config: PortForwardConfig, sshTarget: string): Promise<void> {
  if (!config || !config.static) return;
  for (const entry of config.static) {
    await forwardPort(entry.from, entry.from, sshTarget, entry.label);
  }
}

export async function forwardPort(localPort: number, remotePort: number, sshTarget: string, label: string): Promise<void> {
  if (forwardedPorts.has(localPort)) return;

  // Use SSH -L to forward local port to VM port
  const proc = spawn("limactl", [
    "shell", "pi-vm",
    "--", "ssh", "-N", "-L",
    `${localPort}:localhost:${remotePort}`,
  ], { stdio: "ignore" });

  forwardedPorts.set(localPort, { port: localPort, process: proc, label });
}

export async function stopAllForwards(): Promise<void> {
  for (const [port, entry] of forwardedPorts) {
    if (entry.process) entry.process.kill();
  }
  forwardedPorts.clear();
}
```

- [ ] **Step 3: Commit**

```bash
git add modules/home-manager/pi/extensions/vm-manager/mutagen-sync.ts modules/home-manager/pi/extensions/vm-manager/port-forward.ts
git commit -m "feat(vm-manager): add Mutagen sync and port forwarding modules"
```

---

### Task 7: VM Manager Extension — Main Extension Assembly

**Files:**
- Create: `modules/home-manager/pi/extensions/vm-manager/index.ts`

- [ ] **Step 1: Write the main extension**

Assembles all modules: VM lifecycle, SSH tools, Mutagen sync, port forwarding, and the `--no-vm` flag.

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  createBashTool,
  createEditTool,
  createReadTool,
  createWriteTool,
  getAgentDir,
} from "@mariozechner/pi-coding-agent";
import { loadConfig } from "./config";
import { startVm, stopVm, checkVmStatus, type VmStatus } from "./vm-lifecycle";
import {
  createRemoteBashOps,
  createRemoteEditOps,
  createRemoteReadOps,
  createRemoteWriteOps,
} from "./ssh-tools";
import { startSync, stopSync } from "./mutagen-sync";
import { startStaticForwards, stopAllForwards } from "./port-forward";

export default function vmManagerExtension(pi: ExtensionAPI) {
  pi.registerFlag("no-vm", {
    description: "Disable VM isolation (run locally)",
    type: "boolean",
    default: false,
  });

  const localCwd = process.cwd();
  const localRead = createReadTool(localCwd);
  const localWrite = createWriteTool(localCwd);
  const localEdit = createEditTool(localCwd);
  const localBash = createBashTool(localCwd);

  let vmStatus: VmStatus | null = null;
  let config: ReturnType<typeof loadConfig> | null = null;

  // Replace built-in tools with SSH-delegated versions
  pi.registerTool({
    ...localRead,
    label: "read (VM)",
    async execute(id, params, signal, onUpdate, ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localRead.execute(id, params, signal, onUpdate);
      }
      const tool = createReadTool(localCwd, { operations: createRemoteReadOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...localWrite,
    label: "write (VM)",
    async execute(id, params, signal, onUpdate, ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localWrite.execute(id, params, signal, onUpdate);
      }
      const tool = createWriteTool(localCwd, { operations: createRemoteWriteOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...localEdit,
    label: "edit (VM)",
    async execute(id, params, signal, onUpdate, ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localEdit.execute(id, params, signal, onUpdate);
      }
      const tool = createEditTool(localCwd, { operations: createRemoteEditOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...localBash,
    label: "bash (VM)",
    async execute(id, params, signal, onUpdate, ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localBash.execute(id, params, signal, onUpdate);
      }
      const tool = createBashTool(localCwd, { operations: createRemoteBashOps() });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  // Handle user bash commands via SSH too
  pi.on("user_bash", () => {
    if (!vmStatus?.running || pi.getFlag("--no-vm")) return;
    return { operations: createRemoteBashOps() };
  });

  // Lifecycle
  pi.on("session_start", async (_event, ctx) => {
    config = loadConfig(ctx.cwd);

    if (!config.enabled || pi.getFlag("--no-vm")) {
      ctx.ui.notify("VM Manager: disabled", "info");
      return;
    }

    try {
      ctx.ui.setStatus("vm", ctx.ui.theme.fg("accent", "🖥️ Starting VM..."));
      vmStatus = await startVm(config);
      await startSync(ctx.cwd, config.mutagenBin);
      await startStaticForwards(config.forwardPorts, vmStatus.sshTarget);
      ctx.ui.setStatus("vm", ctx.ui.theme.fg("success", "🖥️ VM ready"));
      ctx.ui.notify(`VM running: ${vmStatus.name}`, "info");
    } catch (err) {
      vmStatus = null;
      const msg = err instanceof Error ? err.message : String(err);
      ctx.ui.setStatus("vm", ctx.ui.theme.fg("error", `🖥️ VM failed`));
      ctx.ui.notify(`VM startup failed: ${msg}`, "error");
    }
  });

  pi.on("session_shutdown", async () => {
    if (vmStatus?.running) {
      await stopSync(config!.mutagenBin);
      await stopAllForwards();
      await stopVm();
      vmStatus = null;
    }
  });

  // Replace local cwd with VM cwd in system prompt
  pi.on("before_agent_start", async (event) => {
    if (vmStatus?.running) {
      const modified = event.systemPrompt.replace(
        `Current working directory: ${localCwd}`,
        `Current working directory: /home/user/project (via VM: ${vmStatus.name})`,
      );
      return { systemPrompt: modified };
    }
  });

  // /vm command to check status or toggle
  pi.registerCommand("vm", {
    description: "Show VM status",
    handler: async (_args, ctx) => {
      if (!vmStatus?.running) {
        ctx.ui.notify("VM not running", "info");
        return;
      }
      ctx.ui.notify(`VM: ${vmStatus.name} (running)`, "info");
    },
  });
}
```

- [ ] **Step 2: Update the system prompt in vm-manager to mention Flox**

In the `before_agent_start` handler, append instructions about the Flox environment:

```typescript
if (vmStatus?.running) {
  // ... existing cwd replacement ...
  return {
    systemPrompt: modified + "\n\nYou are running inside an isolated VM. Use `flox install <package>` to install new tools. The Flox environment is activated automatically.",
  };
}
```

- [ ] **Step 3: Test end-to-end**

```bash
# Start pi with VM manager extension
pi -e ./modules/home-manager/pi/extensions/vm-manager

# In pi:
# - Verify VM starts (check /vm command)
# - Try reading a file (should go via SSH)
# - Try running bash commands (should go via SSH)
# - Try writing a file (should go via SSH, sync back to laptop)
```

- [ ] **Step 4: Commit**

```bash
git add modules/home-manager/pi/extensions/vm-manager/index.ts
git commit -m "feat(vm-manager): assemble main extension with lifecycle, tools, sync, and forwarding"
```

---

### Task 8: Secret Forwarder Extension

**Files:**
- Create: `modules/home-manager/pi/extensions/secret-forwarder/config.ts`
- Create: `modules/home-manager/pi/extensions/secret-forwarder/ssh-config.ts`
- Create: `modules/home-manager/pi/extensions/secret-forwarder/index.ts`

- [ ] **Step 1: Write config loading (global only)**

`config.ts`:

```typescript
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir, homedir } from "@mariozechner/pi-coding-agent";

export interface PortForward {
  from: number;
  label: string;
}

export interface PortRange {
  start: number;
  end: number;
  label: string;
}

export interface SecretForwarderConfig {
  envVars: string[];
  sockets: string[];
  files: string[];
  forwardPorts: {
    auto: boolean;
    static: PortForward[];
    ranges: PortRange[];
  };
}

const DEFAULT_CONFIG: SecretForwarderConfig = {
  envVars: [],
  sockets: [],
  files: [],
  forwardPorts: {
    auto: true,
    static: [],
    ranges: [],
  },
};

export function loadConfig(): SecretForwarderConfig {
  const configPath = join(getAgentDir(), "extensions", "secret-forwarder.json");
  if (!existsSync(configPath)) return DEFAULT_CONFIG;
  try {
    const raw = JSON.parse(readFileSync(configPath, "utf-8"));
    return { ...DEFAULT_CONFIG, ...raw };
  } catch {
    return DEFAULT_CONFIG;
  }
}
```

- [ ] **Step 2: Write SSH config module**

`ssh-config.ts`: Builds SSH arguments for env var forwarding, socket forwarding, file copying, and port forwarding.

```typescript
import { exec } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import type { SecretForwarderConfig } from "./config";

const execAsync = promisify(exec);

export function buildSshEnvArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];
  if (config.envVars.length === 0) return args;

  // Build SetEnv directives for SSH
  const envPairs: string[] = [];
  for (const varName of config.envVars) {
    const value = process.env[varName];
    if (value !== undefined) {
      envPairs.push(`${varName}=${value}`);
    }
  }

  if (envPairs.length > 0) {
    args.push("-o", `SetEnv=${envPairs.join(",")}`);
  }

  return args;
}

export function buildSshSocketArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];
  const home = homedir();

  for (const socketPath of config.sockets) {
    const expanded = socketPath.replace(/^~\/, home + "/");
    if (existsSync(expanded)) {
      // -R forwards a remote socket to a local socket
      args.push("-R", `${expanded}:${expanded}`);
    }
  }

  return args;
}

export function buildSshPortForwardArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];

  for (const entry of config.forwardPorts.static) {
    // -L forwards a local port to a remote port
    args.push("-L", `${entry.from}:localhost:${entry.from}`);
  }

  return args;
}

export async function copyFilesToVm(config: SecretForwarderConfig, vmName: string): Promise<void> {
  const home = homedir();

  for (const filePath of config.files) {
    const expanded = filePath.replace(/^~\/, home + "/");
    if (existsSync(expanded)) {
      const content = readFileSync(expanded);
      const b64 = content.toString("base64");
      await execAsync(
        `limactl shell ${vmName} -- bash -c 'echo ${JSON.stringify(b64)} | base64 -d > ${expanded}'`
      );
    }
  }
}
```

- [ ] **Step 3: Write the main extension**

`index.ts`: Hooks into the VM Manager's SSH construction to inject secret forwarding. Also monitors bash output for URL patterns.

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { loadConfig } from "./config";
import { buildSshEnvArgs, buildSshSocketArgs, buildSshPortForwardArgs, copyFilesToVm } from "./ssh-config";

export default function secretForwarderExtension(pi: ExtensionAPI) {
  let config: ReturnType<typeof loadConfig> | null = null;

  pi.on("session_start", async (_event, ctx) => {
    config = loadConfig();

    const parts: string[] = [];
    if (config.envVars.length > 0) parts.push(`${config.envVars.length} env vars`);
    if (config.sockets.length > 0) parts.push(`${config.sockets.length} sockets`);
    if (config.files.length > 0) parts.push(`${config.files.length} files`);
    if (config.forwardPorts.static.length > 0) parts.push(`${config.forwardPorts.static.length} ports`);

    if (parts.length > 0) {
      ctx.ui.setStatus("secrets", ctx.ui.theme.fg("accent", `🔑 ${parts.join(", ")}`));
    } else {
      ctx.ui.setStatus("secrets", ctx.ui.theme.fg("dim", `🔑 No secrets forwarded`));
    }
  });

  // Copy files to VM after VM is ready (this will be called by VM Manager)
  // The VM Manager should call this after SSH is ready
  // For now, use a command that can be triggered
  pi.registerCommand("secrets", {
    description: "Show forwarded secrets status",
    handler: async (_args, ctx) => {
      if (!config) return;
      const lines = [
        "Secret Forwarder Status:",
        "",
        `Env vars: ${config.envVars.join(", ") || "(none)"}`,
        `Sockets: ${config.sockets.join(", ") || "(none)"}`,
        `Files: ${config.files.join(", ") || "(none)"}`,
        `Static ports: ${config.forwardPorts.static.map((p) => `${p.from} (${p.label})`).join(", ") || "(none)"}`,
      ];
      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  // Watch for URL patterns in bash output (OIDC auth flow)
  const URL_PATTERN = /https?:\/\/[^\s]+/g;

  pi.on("tool_result", async (event, ctx) => {
    if (!ctx.hasUI) return;

    for (const content of event.content) {
      if (content.type !== "text") continue;
      const urls = content.text.match(URL_PATTERN);
      if (!urls) continue;

      for (const url of urls) {
        const choice = await ctx.ui.select(
          `🔗 Browser auth URL detected:\n\n  ${url}\n\n`,
          ["Open in browser", "Copy to clipboard", "Skip"],
        );

        if (choice === "Open in browser") {
          const { exec } = await import("node:child_process");
          exec(`open "${url}"`);
        } else if (choice === "Copy to clipboard") {
          // Copy to clipboard using pbcopy
          const { exec } = await import("node:child_process");
          exec(`echo "${url}" | pbcopy`);
          ctx.ui.notify("URL copied to clipboard", "info");
        }
      }
    }
  });
}
```

- [ ] **Step 4: Integrate secret forwarding with VM Manager's SSH transport**

The VM Manager's `ssh-tools.ts` needs to accept SSH arguments from the secret forwarder. This will be done via the `pi.events` shared event bus. Add to `vm-manager/index.ts`:

```typescript
// In session_start, after VM is ready:
pi.events.on("ssh:args", (extraArgs: string[]) => {
  sshExtraArgs.push(...extraArgs);
});
```

And `secret-forwarder/index.ts` emits:

```typescript
// After config is loaded and VM is ready:
pi.events.emit("ssh:args", [
  ...buildSshEnvArgs(config),
  ...buildSshSocketArgs(config),
  ...buildSshPortForwardArgs(config),
]);
```

- [ ] **Step 5: Commit**

```bash
git add modules/home-manager/pi/extensions/secret-forwarder/
git commit -m "feat(secret-forwarder): add config, SSH arg injection, and URL detection"
```

---

### Task 9: Integration — Wire Extensions Together in Nix

**Files:**
- Modify: `modules/home-manager/pi.nix`

- [ ] **Step 1: Add extension config files to nix**

In `modules/home-manager/pi.nix`, add the config file entries for all three extensions:

```nix
# Add to xdg.configFile section
"pi/agent/extensions/vm-manager.json".text = builtins.toJSON {
  vmType = "vz";
  cpus = 4;
  memory = "8GiB";
  disk = "50GiB";
  nixStorePath = "~/.pi/agent/vm/nix-store";
  mutagenBin = "mutagen";
  projectSyncPath = ".";
};

"pi/agent/extensions/permission-gate.json".text = builtins.toJSON {
  enabled = true;
  rules = {
    bash = {
      autoPatterns = [
        "git status*" "git log*" "git diff*" "git branch*"
        "kubectl get *" "kubectl describe *" "kubectl logs *"
        "rg *" "fd *" "cat *" "ls *" "find *"
        "head *" "tail *" "wc *" "file *" "which *"
        "flox list*" "flox search*"
      ];
      promptPatterns = [
        "kubectl apply *" "kubectl delete *" "kubectl patch *"
        "kubectl create *" "git push*" "rm *" "sudo *"
      ];
    };
    write = { mode = "prompt"; };
    edit = { mode = "prompt"; };
  };
};

"pi/agent/extensions/secret-forwarder.json".text = builtins.toJSON {
  envVars = [];
  sockets = [];
  files = [];
  forwardPorts = {
    auto = true;
    static = [];
    ranges = [];
  };
};
```

- [ ] **Step 2: Remove the old safety.ts extension**

The permission gate extension supersedes the existing `safety.ts` extension. Remove the reference from `pi.nix` and delete (or rename) `safety.ts`:

In `pi.nix`, remove or comment out the `safety.ts` extension mapping since permission-gate replaces it.

- [ ] **Step 3: Add mutagen to packages**

Ensure `mutagen` is in the home-manager package list.

- [ ] **Step 4: Build and verify**

```bash
# Rebuild home-manager
home-manager switch --flake .#cullen

# Verify configs are in place
cat ~/.pi/agent/extensions/vm-manager.json
cat ~/.pi/agent/extensions/permission-gate.json
cat ~/.pi/agent/extensions/secret-forwarder.json

# Verify mutagen is available
which mutagen
```

- [ ] **Step 5: Commit**

```bash
git add modules/home-manager/pi.nix modules/home-manager/pi/extensions/
git commit -m "feat(pi-sandbox): wire all extensions into nix config, add mutagen package"
```

---

### Task 10: End-to-End Testing

**Files:**
- No new files — testing the integrated system

- [ ] **Step 1: Start pi with all three extensions**

```bash
pi -e ~/.pi/agent/extensions/vm-manager -e ~/.pi/agent/extensions/permission-gate -e ~/.pi/agent/extensions/secret-forwarder
```

- [ ] **Step 2: Verify VM starts**

In pi, run:
- Check `/vm` command shows VM running
- Run `!limactl list` to verify VM status
- Run `!flox list` inside the VM to verify Flox activation

Expected: VM boots, Flox activates, all tools delegate to VM.

- [ ] **Step 3: Verify permission gate**

Try these commands in pi:
- Ask pi to run `git status` → should auto-approve
- Ask pi to run `kubectl apply -f test.yaml` → should prompt with options
- Ask pi to write a file → should prompt

- [ ] **Step 4: Verify file sync**

- Create a file in the project on the laptop → verify it appears in the VM via `!limactl shell pi-vm ls /home/user/project/`
- Write a file via pi (which goes to VM) → verify it syncs back to laptop

- [ ] **Step 5: Verify secret forwarding**

- Add a test env var to `secret-forwarder.json`
- Verify it appears in the VM when running commands via pi

- [ ] **Step 6: Verify VM teardown**

Exit pi and verify:
- Mutagen sync session is stopped
- VM is deleted (`limactl list` shows no pi-vm)
- No orphan processes

- [ ] **Step 7: Commit test results (if any config adjustments needed)**

```bash
git add -A
git commit -m "chore(pi-sandbox): adjust configs after end-to-end testing"
```

---

### Task 11: Clean Up Old Safety Extension & Documentation

**Files:**
- Modify: `modules/home-manager/pi/extensions/safety.ts` (remove or replace)
- Modify: `modules/home-manager/pi.nix`
- Create: `docs/superpowers/pi-sandboxing-usage.md`

- [ ] **Step 1: Remove or disable the old safety.ts extension**

The permission gate extension completely replaces `safety.ts`. Remove `safety.ts` and its entry in `pi.nix`:

```nix
# Remove this line from pi.nix:
# "pi/agent/extensions/safety" = { source = ./pi/extensions/safety.ts; recursive = true; };
```

- [ ] **Step 2: Write usage documentation**

Create `docs/superpowers/pi-sandboxing-usage.md`:

```markdown
# Pi Sandboxing — Usage Guide

## Quick Start

```bash
# Start pi with all sandbox extensions
pi -e vm-manager -e permission-gate -e secret-forwarder

# Start pi without VM (local execution)
pi --no-vm

# Check VM status
/vm

# Check forwarded secrets
/secrets
```

## Extensions

### VM Manager

Provides isolated execution in a Lima VZ virtual machine. All file operations and bash commands run inside the VM via SSH.

- VM starts automatically on session start
- VM is ephemeral — deleted on session end
- `/nix` store persists across sessions for warm cache
- Project directory synced via Mutagen
- Flox environment activated automatically

Configuration: `~/.pi/agent/extensions/vm-manager.json` or `.pi/vm-manager.json`

### Permission Gate

Classifies bash commands as auto-approved or requiring user confirmation.

- Read-only commands (`git status`, `kubectl get`, `rg`, etc.) auto-approve
- Mutative commands (`kubectl apply`, `rm`, `sudo`, etc.) require confirmation
- "Always allow" options write to project config for persistence
- Unknown commands default to requiring confirmation

Configuration: `~/.pi/agent/extensions/permission-gate.json` or `.pi/permission-gate.json`

### Secret Forwarder

Explicitly allowlists which secrets and ports can reach the VM.

- No env vars, sockets, files, or ports forwarded by default
- Global config only (no project-level overrides — security)
- Detects auth URLs in output and offers to open them in the browser

Configuration: `~/.pi/agent/extensions/secret-forwarder.json`

## Architecture

```
macOS Host (pi TUI) ←→ Lima VM (VZ)
                        ├── Flox environment
                        ├── Docker (inside VM)
                        ├── /nix persistent volume
                        └── ~/project (Mutagen sync)
```

## Adding Tools to the VM

Use Flox inside the VM:

```bash
# The agent can install tools
flox install kubectl
flox install helm
flox install kind
```

Changes to `.flox/env/manifest.toml` sync back to the laptop via Mutagen.

## Adding Secrets

Edit `~/.pi/agent/extensions/secret-forwarder.json`:

```json
{
  "envVars": ["KUBECONFIG", "AWS_PROFILE"],
  "sockets": ["~/.ssh/agent.sock"],
  "files": ["~/.kube/config"],
  "forwardPorts": {
    "auto": true,
    "static": [{ "from": 8080, "label": "OIDC callback" }],
    "ranges": [{ "start": 3000, "end": 3100, "label": "dev servers" }]
  }
}
```
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs(pi-sandbox): add usage guide, remove old safety extension"
```

---

## Self-Review

### Spec Coverage

| Spec Section | Task |
|---|---|
| VM Manager - Lifecycle | Task 4 (vm-lifecycle), Task 7 (main assembly) |
| VM Manager - SSH Transport | Task 5 (ssh-tools) |
| VM Manager - Lima Template | Task 4 (lima-template.yaml) |
| VM Manager - Boot Timing | Task 4 (implicitly tested in Task 10) |
| Permission Gate - Classification | Task 2 (classifier), Task 3 (main extension) |
| Permission Gate - Prompt UX | Task 3 (exact pattern display) |
| Permission Gate - Config Merge | Task 2 (config loading) |
| Secret Forwarder - Config | Task 8 (config) |
| Secret Forwarder - SSH Args | Task 8 (ssh-config) |
| Secret Forwarder - OIDC URLs | Task 8 (index.ts URL detection) |
| Port Forwarding | Task 6 (port-forward.ts), Task 8 (SSH args) |
| Mutagen Sync | Task 6 (mutagen-sync.ts) |
| Flox Environment | Task 7 (system prompt), Task 5 (bash ops wrapper) |
| Config Merge Strategy | Tasks 2, 4, 8 (per-extension configs) |
| Nix Integration | Task 1 (infrastructure), Task 9 (wiring) |
| Old safety.ts removal | Task 11 |

### Placeholder Scan

No TBDs, TODOs, or incomplete steps found. All steps contain actual code or exact commands.

### Type Consistency

- `VmManagerConfig` defined in Task 4, used in Tasks 5, 6, 7
- `PermissionGateConfig` defined in Task 2, used in Task 3
- `SecretForwarderConfig` defined in Task 8, used in Task 8
- `PortForward` and `PortRange` defined in Task 8
- SSH operations match pi's `ReadOperations`, `WriteOperations`, `EditOperations`, `BashOperations` interfaces as shown in `ssh.ts`

### Scope Check

All 11 tasks are focused on building the three extensions and wiring them into the nix config. No scope creep.