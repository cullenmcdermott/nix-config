import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import type { Api, Model } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { getAgentDir } from "@mariozechner/pi-coding-agent";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";

interface Preset {
  provider?: string;
  model?: string;
  thinkingLevel?: ThinkingLevel;
  tools?: string[];
  instructions?: string;
  description?: string;
}

type PresetsConfig = Record<string, Preset>;

interface OriginalState {
  model: Model<Api> | undefined;
  thinkingLevel: ThinkingLevel;
  tools: string[];
}

function loadPresets(cwd: string): PresetsConfig {
  const globalPath = join(getAgentDir(), "presets.json");
  const projectPath = join(cwd, ".pi", "presets.json");

  let globalPresets: PresetsConfig = {};
  let projectPresets: PresetsConfig = {};

  if (existsSync(globalPath)) {
    globalPresets = JSON.parse(readFileSync(globalPath, "utf-8")) as PresetsConfig;
  }

  if (existsSync(projectPath)) {
    projectPresets = JSON.parse(readFileSync(projectPath, "utf-8")) as PresetsConfig;
  }

  return { ...globalPresets, ...projectPresets };
}

export default function presetExtension(pi: ExtensionAPI) {
  let presets: PresetsConfig = {};
  let activePresetName: string | undefined;
  let activePreset: Preset | undefined;
  let originalState: OriginalState | undefined;

  function updateStatus(ctx: ExtensionContext) {
    if (activePresetName) {
      ctx.ui.setStatus("preset", ctx.ui.theme.fg("accent", `preset:${activePresetName}`));
    } else {
      ctx.ui.setStatus("preset", undefined);
    }
  }

  async function restoreDefaults(ctx: ExtensionContext) {
    activePresetName = undefined;
    activePreset = undefined;

    if (originalState) {
      if (originalState.model) await pi.setModel(originalState.model);
      pi.setThinkingLevel(originalState.thinkingLevel);
      pi.setActiveTools(originalState.tools);
    } else {
      pi.setActiveTools(["read", "bash", "edit", "write"]);
      pi.setThinkingLevel("high");
    }

    updateStatus(ctx);
  }

  async function applyPreset(name: string, preset: Preset, ctx: ExtensionContext) {
    if (!originalState) {
      originalState = {
        model: ctx.model,
        thinkingLevel: pi.getThinkingLevel(),
        tools: pi.getActiveTools(),
      };
    }

    if (preset.provider && preset.model) {
      const model = ctx.modelRegistry.find(preset.provider, preset.model);
      if (model) {
        const success = await pi.setModel(model);
        if (!success) {
          ctx.ui.notify(`Preset ${name}: no API key for ${preset.provider}/${preset.model}`, "warning");
        }
      } else {
        ctx.ui.notify(`Preset ${name}: model ${preset.provider}/${preset.model} not found`, "warning");
      }
    }

    if (preset.thinkingLevel) {
      pi.setThinkingLevel(preset.thinkingLevel);
    }

    if (preset.tools && preset.tools.length > 0) {
      const validTools = new Set(pi.getAllTools().map((tool) => tool.name));
      const tools = preset.tools.filter((tool) => validTools.has(tool));
      if (tools.length > 0) {
        pi.setActiveTools(tools);
      }
    }

    activePresetName = name;
    activePreset = preset;
    updateStatus(ctx);
  }

  async function showSelector(ctx: ExtensionContext) {
    const names = Object.keys(presets).sort();
    if (names.length === 0) {
      ctx.ui.notify("No presets configured", "warning");
      return;
    }

    const options = [
      ...names.map((name) => {
        const description = presets[name]?.description;
        const active = name === activePresetName ? " (active)" : "";
        return description ? `${name}${active} — ${description}` : `${name}${active}`;
      }),
      "none — clear active preset",
    ];

    const selected = await ctx.ui.select("Select preset", options);
    if (!selected) return;

    if (selected.startsWith("none")) {
      await restoreDefaults(ctx);
      ctx.ui.notify("Preset cleared", "info");
      return;
    }

    const name = selected.split(" — ")[0]?.replace(/ \(active\)$/, "");
    if (!name) return;

    const preset = presets[name];
    if (!preset) return;

    await applyPreset(name, preset, ctx);
    ctx.ui.notify(`Preset ${name} activated`, "info");
  }

  pi.registerCommand("preset", {
    description: "Switch between plan / implement / review presets",
    handler: async (args, ctx) => {
      const name = args?.trim() ?? "";
      if (!name) {
        await showSelector(ctx);
        return;
      }

      if (name === "none" || name === "clear") {
        await restoreDefaults(ctx);
        ctx.ui.notify("Preset cleared", "info");
        return;
      }

      const preset = presets[name];
      if (!preset) {
        const available = Object.keys(presets).sort().join(", ");
        ctx.ui.notify(`Unknown preset ${name}. Available: ${available}`, "error");
        return;
      }

      await applyPreset(name, preset, ctx);
      ctx.ui.notify(`Preset ${name} activated`, "info");
    },
  });

  pi.on("before_agent_start", async (event) => {
    if (!activePreset?.instructions) return;
    return {
      systemPrompt: `${event.systemPrompt}\n\n${activePreset.instructions}`,
    };
  });

  pi.on("session_start", async (_event, ctx) => {
    presets = loadPresets(ctx.cwd);
    updateStatus(ctx);
  });
}
