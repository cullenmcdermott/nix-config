import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { createConnection } from "node:net";

interface BridgeResponse {
  ok: boolean;
  value?: string;
  error?: string;
}

function bridgeRequest(
  sockPath: string,
  token: string,
  payload: Record<string, unknown>,
): Promise<BridgeResponse> {
  return new Promise((resolve, reject) => {
    const sock = createConnection(sockPath, () => {
      const msg = JSON.stringify({ token, ...payload }) + "\n";
      sock.write(msg);
    });

    let data = "";
    sock.on("data", (chunk) => {
      data += chunk.toString();
    });
    sock.on("end", () => {
      try {
        resolve(JSON.parse(data.trim()));
      } catch {
        reject(new Error(`Invalid bridge response: ${data}`));
      }
    });
    sock.on("error", (err) => {
      reject(new Error(`Bridge connection failed: ${err.message}`));
    });

    // Safety timeout — bridge requests must complete within 10s
    setTimeout(() => {
      sock.destroy();
      reject(new Error("Bridge request timed out"));
    }, 10000);
  });
}

export default function hostBridgeExtension(pi: ExtensionAPI) {
  const sockPath = process.env.POMP_BRIDGE_SOCK;
  const token = process.env.POMP_BRIDGE_TOKEN;

  if (!sockPath || !token) {
    // Not running inside pomp — extension is a no-op
    return;
  }

  // Watch tool output for URLs (OIDC auth flows, dev server links, etc.)
  const URL_PATTERN = /https?:\/\/[^\s"'<>]+/g;

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
        if (parsed.protocol !== "http:" && parsed.protocol !== "https:") continue;

        const choice = await ctx.ui.select(
          `Browser auth URL detected:\n\n  ${url}\n\n`,
          ["Open on host", "Skip"],
        );

        if (choice === "Open on host") {
          try {
            const resp = await bridgeRequest(sockPath, token, {
              type: "open_url",
              url,
            });
            if (!resp.ok) {
              ctx.ui.notify(`Failed to open URL: ${resp.error}`, "error");
            }
          } catch (err) {
            ctx.ui.notify(
              `Bridge error: ${err instanceof Error ? err.message : String(err)}`,
              "error",
            );
          }
        }
      }
    }
  });

  // /secret command — fetch a 1Password secret on demand
  pi.registerCommand("secret", {
    description: "Fetch a secret from the host via 1Password (op://...)",
    handler: async (args, ctx) => {
      const ref = args.trim();
      if (!ref) {
        ctx.ui.notify("Usage: /secret op://vault/item/field", "info");
        return;
      }
      if (!ref.startsWith("op://")) {
        ctx.ui.notify("Secret ref must start with op://", "error");
        return;
      }
      try {
        const resp = await bridgeRequest(sockPath, token, {
          type: "secret",
          ref,
        });
        if (resp.ok) {
          // Derive an env var name from the last path segment
          const varName =
            ref.split("/").pop()?.toUpperCase().replace(/[^A-Z0-9_]/g, "_") ??
            "SECRET";
          process.env[varName] = resp.value;
          ctx.ui.notify(`Secret loaded into env as ${varName}`, "info");
        } else {
          ctx.ui.notify(`Failed: ${resp.error}`, "error");
        }
      } catch (err) {
        ctx.ui.notify(
          `Bridge error: ${err instanceof Error ? err.message : String(err)}`,
          "error",
        );
      }
    },
  });

  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setStatus(
      "bridge",
      ctx.ui.theme.fg("accent", "Host bridge active"),
    );
  });
}
