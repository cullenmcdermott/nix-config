import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import {
  createBashToolDefinition,
  createEditToolDefinition,
  createReadToolDefinition,
  createWriteToolDefinition,
} from "@oh-my-pi/pi-coding-agent";
import { loadConfig } from "./config.js";
import {
  startVm,
  stopVm,
  checkVmStatus,
  type VmStatus,
} from "./vm-lifecycle.js";
import {
  createRemoteBashOps,
  createRemoteEditOps,
  createRemoteReadOps,
  createRemoteWriteOps,
} from "./ssh-tools.js";
import { startSync, stopSync } from "./mutagen-sync.js";
import { startStaticForwards, stopAllForwards } from "./port-forward.js";

export default function vmManagerExtension(pi: ExtensionAPI) {
  pi.registerFlag("no-vm", {
    description: "Disable VM isolation (run locally)",
    type: "boolean",
    default: false,
  });

  const localCwd = process.cwd();
  const localRead = createReadToolDefinition(localCwd);
  const localWrite = createWriteToolDefinition(localCwd);
  const localEdit = createEditToolDefinition(localCwd);
  const localBash = createBashToolDefinition(localCwd);

  let vmStatus: VmStatus | null = null;
  let config: ReturnType<typeof loadConfig> | null = null;

  // Replace built-in tools with SSH-delegated versions
  pi.registerTool({
    ...localRead,
    label: "read (VM)",
    async execute(id, params, signal, onUpdate, _ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localRead.execute(id, params, signal, onUpdate);
      }
      const tool = createReadToolDefinition(localCwd, {
        operations: createRemoteReadOps(),
      });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...localWrite,
    label: "write (VM)",
    async execute(id, params, signal, onUpdate, _ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localWrite.execute(id, params, signal, onUpdate);
      }
      const tool = createWriteToolDefinition(localCwd, {
        operations: createRemoteWriteOps(),
      });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...localEdit,
    label: "edit (VM)",
    async execute(id, params, signal, onUpdate, _ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localEdit.execute(id, params, signal, onUpdate);
      }
      const tool = createEditToolDefinition(localCwd, {
        operations: createRemoteEditOps(),
      });
      return tool.execute(id, params, signal, onUpdate);
    },
  });

  pi.registerTool({
    ...localBash,
    label: "bash (VM)",
    async execute(id, params, signal, onUpdate, _ctx) {
      if (!vmStatus?.running || pi.getFlag("--no-vm")) {
        return localBash.execute(id, params, signal, onUpdate);
      }
      const tool = createBashToolDefinition(localCwd, {
        operations: createRemoteBashOps(),
      });
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
      ctx.ui.setStatus("vm", ctx.ui.theme.fg("error", "🖥️ VM failed"));
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
      return {
        systemPrompt:
          modified +
          "\n\nYou are running inside an isolated VM. Use `flox install <package>` to install new tools. The Flox environment is activated automatically.",
      };
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
