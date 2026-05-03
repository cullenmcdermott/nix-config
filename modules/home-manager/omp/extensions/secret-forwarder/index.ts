import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { loadConfig } from "./config.js";
import {
  buildSshEnvArgs,
  buildSshSocketArgs,
  buildSshPortForwardArgs,
  copyFilesToVm,
} from "./ssh-config.js";

export default function secretForwarderExtension(pi: ExtensionAPI) {
  let config: ReturnType<typeof loadConfig> | null = null;

  pi.on("session_start", async (_event, ctx) => {
    config = loadConfig(pi.pi.getAgentDir());

    const parts: string[] = [];
    if (config.envVars.length > 0) parts.push(`${config.envVars.length} env vars`);
    if (config.sockets.length > 0) parts.push(`${config.sockets.length} sockets`);
    if (config.files.length > 0) parts.push(`${config.files.length} files`);
    if (config.forwardPorts.static.length > 0)
      parts.push(`${config.forwardPorts.static.length} ports`);

    if (parts.length > 0) {
      ctx.ui.setStatus(
        "secrets",
        ctx.ui.theme.fg("accent", `🔑 ${parts.join(", ")}`),
      );
    } else {
      ctx.ui.setStatus("secrets", ctx.ui.theme.fg("dim", `🔑 No secrets forwarded`));
    }
  });

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
        let parsed: URL;
        try {
          parsed = new URL(url);
        } catch {
          continue;
        }
        if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
          ctx.ui.notify(`Blocked non-http URL scheme: ${parsed.protocol}`, "error");
          continue;
        }

        const choice = await ctx.ui.select(
          `🔗 Browser auth URL detected:\n\n  ${url}\n\n`,
          ["Open in browser", "Copy to clipboard", "Skip"],
        );

        const { spawn } = await import("node:child_process");
        if (choice === "Open in browser") {
          spawn("open", [url]);
        } else if (choice === "Copy to clipboard") {
          const p = spawn("pbcopy", [], { stdio: ["pipe", "ignore", "ignore"] });
          p.stdin!.write(url);
          p.stdin!.end();
          ctx.ui.notify("URL copied to clipboard", "info");
        }
      }
    }
  });
}
