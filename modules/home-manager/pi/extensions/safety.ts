import { resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const DANGEROUS_BASH_PATTERNS: RegExp[] = [
  /\brm\s+(-rf?|--recursive)\b/i,
  /\bsudo\b/i,
  /\b(chmod|chown)\b.*\b777\b/i,
  /\bmkfs\b/i,
  /\bdd\b.*\bof=\/dev\//i,
  /\bshutdown\b/i,
  /\breboot\b/i,
  /\bhalt\b/i,
  /\bpoweroff\b/i,
];

const PROTECTED_PATH_PATTERNS: RegExp[] = [
  /(^|\/)\.env($|\.)/i,
  /(^|\/)(secrets?|credentials?)\.(json|ya?ml|toml)$/i,
  /(^|\/)(id_rsa|id_ed25519|known_hosts|authorized_keys)$/i,
  /\/\.ssh\//,
  /\/\.aws\//,
  /\/\.gnupg\//,
  /\/\.config\/pi\/agent\/auth\.json$/,
  /\/\.claude\//,
];

function isProtectedPath(path: string): boolean {
  return PROTECTED_PATH_PATTERNS.some((pattern) => pattern.test(path));
}

function getPathFromToolInput(toolName: string, input: unknown): string | undefined {
  if (!input || typeof input !== "object") return undefined;
  const record = input as Record<string, unknown>;

  if ((toolName === "read" || toolName === "write" || toolName === "edit") && typeof record.path === "string") {
    return record.path;
  }

  return undefined;
}

async function confirmDirtyRepo(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  action: string,
): Promise<{ cancel: boolean } | undefined> {
  const { stdout, code } = await pi.exec("git", ["status", "--porcelain"]);
  if (code !== 0) return undefined;

  const changed = stdout
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

  if (changed.length === 0) return undefined;

  if (!ctx.hasUI) return { cancel: true };

  const choice = await ctx.ui.select(
    `You have ${changed.length} uncommitted file(s). Continue with ${action}?`,
    ["Proceed", "Cancel"],
  );

  if (choice !== "Proceed") {
    ctx.ui.notify("Cancelled because the repo has uncommitted changes", "warning");
    return { cancel: true };
  }

  return undefined;
}

export default function safetyExtension(pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "bash") {
      const command = String((event.input as Record<string, unknown>).command ?? "");
      const dangerous = DANGEROUS_BASH_PATTERNS.some((pattern) => pattern.test(command));

      if (dangerous) {
        if (!ctx.hasUI) {
          return { block: true, reason: "Dangerous bash command blocked (no UI confirmation available)" };
        }

        const choice = await ctx.ui.select(
          `Dangerous bash command detected:\n\n${command}\n\nAllow it?`,
          ["Allow", "Block"],
        );

        if (choice !== "Allow") {
          return { block: true, reason: "Blocked by safety extension" };
        }
      }
    }

    if (event.toolName === "read" || event.toolName === "write" || event.toolName === "edit") {
      const rawPath = getPathFromToolInput(event.toolName, event.input);
      if (!rawPath) return undefined;

      const fullPath = resolve(ctx.cwd, rawPath);
      if (isProtectedPath(fullPath)) {
        return {
          block: true,
          reason: `Access to protected path is blocked by safety extension: ${rawPath}`,
        };
      }
    }

    return undefined;
  });

  pi.on("session_before_switch", async (event, ctx) => {
    const action = event.reason === "new" ? "starting a new session" : "switching sessions";
    return confirmDirtyRepo(pi, ctx, action);
  });

  pi.on("session_before_fork", async (_event, ctx) => {
    return confirmDirtyRepo(pi, ctx, "forking the session");
  });
}
