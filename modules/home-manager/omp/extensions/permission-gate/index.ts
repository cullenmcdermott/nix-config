import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { loadConfig, savePattern } from "./config.js";
import { classifyTool } from "./classifier.js";
import type { PermissionGateConfig } from "./config.js";
import { minimatch } from "./config.js";

export default function permissionGateExtension(pi: ExtensionAPI) {
  let config: PermissionGateConfig | null = null;

  pi.on("session_start", async (_event, ctx) => {
    config = loadConfig(ctx.cwd, pi.pi.getAgentDir());
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
      if (event.toolName === "read" || event.toolName === "search" || event.toolName === "find") {
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
      savePattern(ctx.cwd, event.toolName, selected.pattern ?? "", "autoPatterns");
      config = loadConfig(ctx.cwd, pi.pi.getAgentDir()); // Reload config
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
    const blockedByGlobal = config.rules.bash.promptPatterns.some((p) => minimatch(command, p));

    if (!blockedByGlobal) {
      options.push({
        label: `Yes (always allow: ${command})`,
        action: "always-exact",
        pattern: command,
      });

      const matchedPattern = config.rules.bash.promptPatterns.find((p) => minimatch(command, p));
      if (matchedPattern) {
        options.push({
          label: `Yes (always allow: ${matchedPattern})`,
          action: "always-pattern",
          pattern: matchedPattern,
        });
      }
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
