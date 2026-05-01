import type { Model } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/**
 * Model Memory Extension
 *
 * Remembers the active model across /new session resets.
 * Without this, /new falls back to the default model configured in settings.
 * With this, /new retains whatever model the user last selected.
 */
export default function modelMemoryExtension(pi: ExtensionAPI) {
  let lastModel: Model<any> | undefined;

  pi.on("model_select", async (event) => {
    lastModel = event.model;
  });

  pi.on("session_start", async (event, ctx) => {
    // Only restore for "new" sessions (not startup, reload, resume, or fork)
    if (event.reason !== "new") return;
    if (!lastModel) return;

    // If the newly created session already has a model that matches our remembered one, skip
    if (ctx.model && ctx.model.id === lastModel.id && ctx.model.provider === lastModel.provider) return;

    const success = await pi.setModel(lastModel);
    if (success) {
      ctx.ui.setStatus("model-memory", ctx.ui.theme.fg("success", `Restored: ${lastModel.provider}/${lastModel.id}`));
      // Clear the status after a short delay
      setTimeout(() => ctx.ui.setStatus("model-memory", undefined), 3000);
    }
  });
}