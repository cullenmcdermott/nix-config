import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { loadConfig } from "./config.js";
import {
  startVm,
  stopVm,
  type VmStatus,
} from "./vm-lifecycle.js";
import { createRemoteBashOps } from "./ssh-tools.js";
import { startSync, stopSync } from "./mutagen-sync.js";
import { loadConfig as loadSecretConfig } from "../secret-forwarder/config.js";
import {
  copyFilesToVm,
  getForwardedEnvRecord,
} from "../secret-forwarder/ssh-config.js";
import { startStaticForwards, stopAllForwards } from "./port-forward.js";

export default function vmManagerExtension(pi: ExtensionAPI) {
  const { Type } = pi.typebox;
  const agentDir = pi.pi.getAgentDir();
  pi.registerFlag("no-vm", {
    description: "Disable VM isolation (run locally)",
    type: "boolean",
    default: false,
  });

  const localCwd = process.cwd();

  let vmStatus: VmStatus | null = null;
  let config: ReturnType<typeof loadConfig> | null = null;
  let extraEnv: Record<string, string> | undefined;

  // Override the built-in bash tool so AI commands run inside the VM.
  // Same name causes this to replace the built-in in the tool registry.
  // Read/write/edit are left as built-ins — mutagen keeps them in sync.
  pi.registerTool({
    name: "bash",
    label: "bash (VM)",
    description:
      "Execute a shell command in a bash shell. When the VM sandbox is active, commands run inside an isolated Linux VM with the Flox environment activated. Use `cwd` to set the working directory.",
    parameters: Type.Object({
      command: Type.String({ description: "command to execute", examples: ["ls -la", "echo hi"] }),
      env: Type.Optional(
        Type.Record(Type.String(), Type.String(), { description: "extra env vars" }),
      ),
      timeout: Type.Optional(Type.Number({ description: "timeout in seconds", default: 300 })),
      cwd: Type.Optional(Type.String({ description: "working directory", examples: ["src/", "/tmp"] })),
      head: Type.Optional(Type.Number({ description: "first n lines of output" })),
      tail: Type.Optional(Type.Number({ description: "last n lines of output" })),
      pty: Type.Optional(Type.Boolean({ description: "run in pty mode" })),
    }),
    async execute(_id, params, signal, onUpdate, _ctx) {
      if (vmStatus?.running && !pi.getFlag("no-vm")) {
        const ops = createRemoteBashOps(extraEnv);
        const chunks: string[] = [];
        const { exitCode } = await ops.exec(params.command, params.cwd ?? localCwd, {
          onData: (data: Buffer) => {
            const text = data.toString();
            chunks.push(text);
            onUpdate?.({ content: [{ type: "text", text }] });
          },
          signal,
          timeout: params.timeout,
        });
        return {
          content: [{ type: "text", text: chunks.join("") }],
          details: { exitCode: exitCode ?? 0 },
        };
      }
      // Local fallback (no-vm flag or VM not yet started)
      return new Promise((resolve) => {
        const child = spawn("bash", ["-c", params.command], {
          cwd: params.cwd ?? localCwd,
          env: { ...process.env, ...(params.env ?? {}) },
          stdio: ["ignore", "pipe", "pipe"],
        });
        const out: string[] = [];
        child.stdout.on("data", (d: Buffer) => {
          const t = d.toString();
          out.push(t);
          onUpdate?.({ content: [{ type: "text", text: t }] });
        });
        child.stderr.on("data", (d: Buffer) => {
          const t = d.toString();
          out.push(t);
          onUpdate?.({ content: [{ type: "text", text: t }] });
        });
        signal?.addEventListener("abort", () => child.kill("SIGKILL"), { once: true });
        child.on("close", (code: number | null) => {
          resolve({
            content: [{ type: "text", text: out.join("") }],
            details: { exitCode: code ?? 1 },
          });
        });
      });
    },
  });

  // Handle user-typed bash commands ($ prefix) via SSH when VM is running.
  pi.on("user_bash", async (event) => {
    if (!vmStatus?.running || pi.getFlag("no-vm")) return;
    const ops = createRemoteBashOps(extraEnv);
    const chunks: Buffer[] = [];
    try {
      const { exitCode } = await ops.exec(event.command, event.cwd, {
        onData: (data: Buffer) => chunks.push(data),
        signal: undefined,
        timeout: 300,
      });
      const output = Buffer.concat(chunks).toString();
      const lines = output.split("\n").length;
      return {
        result: {
          output,
          exitCode: exitCode ?? 0,
          cancelled: false,
          truncated: false,
          totalLines: lines,
          totalBytes: output.length,
          outputLines: lines,
          outputBytes: output.length,
        },
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        result: {
          output: `SSH error: ${msg}`,
          exitCode: 1,
          cancelled: false,
          truncated: false,
          totalLines: 1,
          totalBytes: msg.length,
          outputLines: 1,
          outputBytes: msg.length,
        },
      };
    }
  });

  // Lifecycle
  pi.on("session_start", async (_event, ctx) => {
    config = loadConfig(ctx.cwd, agentDir);

    if (!config.enabled || pi.getFlag("no-vm")) {
      ctx.ui.notify("VM Manager: disabled", "info");
      return;
    }

    ctx.ui.setStatus("vm", ctx.ui.theme.fg("accent", "🖥️ Starting VM..."));
    let vmStarted = false;
    try {
      vmStatus = await startVm(config, agentDir);
      vmStarted = true;
      await startSync(ctx.cwd, config.mutagenBin);
      await startStaticForwards(config.forwardPorts, vmStatus.sshTarget);

      const sfConfig = loadSecretConfig(agentDir);
      await copyFilesToVm(sfConfig, vmStatus.name);
      extraEnv = getForwardedEnvRecord(sfConfig);

      ctx.ui.setStatus("vm", ctx.ui.theme.fg("success", "🖥️ VM ready"));
      ctx.ui.notify(`VM running: ${vmStatus.name}`, "info");
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      ctx.ui.setStatus("vm", ctx.ui.theme.fg("error", "🖥️ VM failed"));
      ctx.ui.notify(`VM startup failed: ${msg}`, "error");
      if (vmStarted) {
        try { await stopVm(); } catch {}
      }
      vmStatus = null;
      throw new Error(`Sandbox initialization failed: ${msg}`);
    }
  });

  pi.on("session_shutdown", async () => {
    if (vmStatus) {
      await stopSync(config!.mutagenBin);
      await stopAllForwards();
      await stopVm();
      vmStatus = null;
    }
  });

  // Patch the system prompt so the agent knows it's operating inside the VM.
  pi.on("before_agent_start", async (event) => {
    if (vmStatus?.running) {
      const modified = event.systemPrompt.replace(
        `Current working directory: ${localCwd}`,
        `Current working directory: /home/user/project (via VM: ${vmStatus.name})`,
      );
      return {
        systemPrompt:
          modified +
          "\n\nYou are running inside an isolated Linux VM. Use `flox install <package>` to install new tools. The Flox environment is activated automatically. File reads/writes operate on the host-synced copy (mutagen keeps them in sync with the VM).",
      };
    }
  });

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
