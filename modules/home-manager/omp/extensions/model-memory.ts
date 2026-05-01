import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { getAgentDir } from "@oh-my-pi/pi-utils";

const STATE_FILE = join(getAgentDir(), "model-memory.json");

interface ModelMemory {
  provider: string;
  id: string;
}

function readPersistedModel(): ModelMemory | undefined {
  try {
    if (!existsSync(STATE_FILE)) return undefined;
    const data = JSON.parse(readFileSync(STATE_FILE, "utf-8") as string) as ModelMemory;
    if (data.provider && data.id) return data;
  } catch {
    // Corrupt or missing file — treat as no prior model
  }
  return undefined;
}

function persistModel(provider: string, id: string): void {
  try {
    writeFileSync(STATE_FILE, JSON.stringify({ provider, id }), "utf-8");
  } catch {
    // Best effort — if we can't write, the next session will just use the default
  }
}

/**
 * Model Memory Extension
 *
 * Remembers the active model across /new session resets.
 * Without this, /new falls back to the default model configured in settings.
 * With this, /new retains whatever model the user last selected.
 *
 * State is persisted to a file because /new reloads extensions from scratch,
 * destroying any in-memory state held in closure variables.
 */
export default function modelMemoryExtension(pi: ExtensionAPI) {
  pi.on("model_select", async (event) => {
    persistModel(event.model.provider, event.model.id);
  });

  pi.on("session_start", async (event, ctx) => {
    // Only restore for "new" sessions (not startup, reload, resume, or fork)
    if (event.reason !== "new") return;

    const remembered = readPersistedModel();
    if (!remembered) return;

    // If the newly created session already has a model that matches our remembered one, skip
    if (ctx.model && ctx.model.id === remembered.id && ctx.model.provider === remembered.provider) return;

    // Look up the full model object from the registry using provider + id
    const model = ctx.modelRegistry.find(remembered.provider, remembered.id);
    if (!model) {
      // Model no longer available (e.g. provider removed)
      return;
    }

    const success = await pi.setModel(model);
    if (success) {
      ctx.ui.setStatus("model-memory", ctx.ui.theme.fg("success", `Restored: ${model.provider}/${model.id}`));
      setTimeout(() => ctx.ui.setStatus("model-memory", undefined), 3000);
    }
  });
}