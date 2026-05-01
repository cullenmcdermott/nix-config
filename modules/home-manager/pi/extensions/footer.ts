import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

// --- Rate limit state ---
interface RateLimitInfo {
  remaining: number | null;
  limit: number | null;
  resetAt: number | null;  // Unix timestamp in seconds
  provider: string;
}

let rateLimit: RateLimitInfo = {
  remaining: null,
  limit: null,
  resetAt: null,
  provider: "",
};

function fmtCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return `${n}`;
}

function ctxBar(pct: number): string {
  // Unicode block characters for a 6-cell progress bar
  const blocks = ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"];
  const width = 6;
  const filled = (pct / 100) * width;
  const fullBlocks = Math.floor(filled);
  const partialIdx = Math.round((filled - fullBlocks) * (blocks.length - 1));
  const emptyBlocks = width - fullBlocks - (partialIdx > 0 ? 1 : 0);

  let bar = "";
  for (let i = 0; i < fullBlocks; i++) bar += blocks[blocks.length - 1];
  if (partialIdx > 0 && fullBlocks < width) bar += blocks[partialIdx];
  for (let i = 0; i < Math.max(0, emptyBlocks); i++) bar += "░";

  return bar;
}

function fmtCtx(used: number, max: number): string {
  const pct = Math.round((used / max) * 100);
  const bar = ctxBar(pct);
  return `${bar} ${pct}%/${fmtCount(max)}`;
}

function shortModelName(model: string): string {
  return model
    .replace(/^claude-/, "c-")
    .replace(/^gpt-/, "")
    .replace(/^gemini-/, "g-")
    .replace(/^github-copilot\//, "")
    .replace(/^opencode-go\//, "");
}

function cleanStatus(status: string): string {
  return status.replace(/^preset:/, "").trim();
}

function fmtRateLimit(info: RateLimitInfo): string | null {
  if (info.remaining === null && info.limit === null) return null;

  const parts: string[] = [];

  if (info.remaining !== null && info.limit !== null) {
    parts.push(`${info.remaining}/${info.limit}`);
  } else if (info.remaining !== null) {
    parts.push(`${info.remaining} left`);
  } else if (info.limit !== null) {
    parts.push(`limit:${info.limit}`);
  }

  if (info.resetAt !== null) {
    const secondsLeft = Math.max(0, info.resetAt - Math.floor(Date.now() / 1000));
    if (secondsLeft > 0) {
      if (secondsLeft >= 3600) {
        parts.push(`resets ${Math.ceil(secondsLeft / 3600)}h`);
      } else if (secondsLeft >= 60) {
        parts.push(`resets ${Math.ceil(secondsLeft / 60)}m`);
      } else {
        parts.push(`resets ${secondsLeft}s`);
      }
    }
  }

  return parts.join(" ");
}

function parseRateLimitHeaders(headers: Record<string, string>, provider: string): RateLimitInfo {
  // Normalize header names (some providers use different casings)
  const get = (name: string): string | undefined => {
    return headers[name] ?? headers[name.toLowerCase()] ?? undefined;
  };

  const remainingStr = get("x-ratelimit-remaining") ?? get("ratelimit-remaining");
  const limitStr = get("x-ratelimit-limit") ?? get("ratelimit-limit");
  const resetStr = get("x-ratelimit-reset") ?? get("ratelimit-reset");

  let remaining: number | null = null;
  let limit: number | null = null;
  let resetAt: number | null = null;

  if (remainingStr) {
    const parsed = parseInt(remainingStr, 10);
    if (!isNaN(parsed)) remaining = parsed;
  }
  if (limitStr) {
    const parsed = parseInt(limitStr, 10);
    if (!isNaN(parsed)) limit = parsed;
  }
  if (resetStr) {
    // x-ratelimit-reset can be a Unix timestamp (seconds) or relative seconds
    const parsed = parseFloat(resetStr);
    if (!isNaN(parsed)) {
      // If it seems like a Unix timestamp (> year 2020), use as-is
      // Otherwise treat as seconds from now
      if (parsed > 1577836800) {
        resetAt = parsed;
      } else {
        resetAt = Math.floor(Date.now() / 1000) + parsed;
      }
    }
  }

  return { remaining, limit, resetAt, provider };
}

function installFooter(pi: ExtensionAPI, ctx: ExtensionContext) {
  ctx.ui.setFooter((tui, theme, footerData) => {
    const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

    return {
      dispose: unsubscribe,
      invalidate() {},
      render(width: number): string[] {
        let inputTokens = 0;
        let outputTokens = 0;
        let totalCost = 0;

        for (const entry of ctx.sessionManager.getBranch()) {
          if (entry.type !== "message" || entry.message.role !== "assistant") continue;
          const message = entry.message as AssistantMessage;
          inputTokens += message.usage.input;
          outputTokens += message.usage.output;
          totalCost += message.usage.cost.total;
        }

        const cwdName = ctx.cwd.split(/[\\/]/).filter(Boolean).pop() ?? ctx.cwd;
        const branch = footerData.getGitBranch();
        const thinking = pi.getThinkingLevel();
        const model = ctx.model ? shortModelName(ctx.model.id) : "no-model";
        const contextUsage = ctx.getContextUsage();
        const statuses = [...footerData.getExtensionStatuses().values()].filter(Boolean).map(cleanStatus);
        const preset = statuses.find((status) => status.length > 0);

        // Left side: cwd + branch + preset
        const leftParts = [theme.fg("accent", cwdName)];
        if (branch) leftParts.push(theme.fg("muted", branch));
        if (preset) leftParts.push(theme.fg("dim", `[${preset}]`));
        const left = leftParts.join("  ");

        // Right side: model + thinking + context + tokens + cost + rate limit
        const rightParts: string[] = [
          theme.fg("muted", model),
          theme.fg("dim", thinking),
        ];

        if (contextUsage && contextUsage.tokens !== null && contextUsage.tokens > 0 && contextUsage.contextWindow > 0) {
          rightParts.push(theme.fg("accent", fmtCtx(contextUsage.tokens, contextUsage.contextWindow)));
        }

        if (inputTokens + outputTokens >= 1000) {
          rightParts.push(theme.fg("dim", `↑${fmtCount(inputTokens)} ↓${fmtCount(outputTokens)}`));
        }

        if (totalCost > 0) {
          rightParts.push(theme.fg("dim", `$${totalCost.toFixed(totalCost < 0.001 ? 4 : 3)}`));
        }

        const rlText = fmtRateLimit(rateLimit);
        if (rlText) {
          rightParts.push(theme.fg("dim", `ℹ${rlText}`));
        }

        const right = rightParts.join("  ");
        const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));

        return [truncateToWidth(`${left}${pad}${right}`, width)];
      },
    };
  });
}

export default function footerExtension(pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    installFooter(pi, ctx);
  });

  pi.on("model_select", async (_event, ctx) => {
    installFooter(pi, ctx);
  });

  // Capture rate limit headers from provider responses
  pi.on("after_provider_response", async (event, ctx) => {
    const provider = ctx.model?.provider ?? "unknown";
    const newInfo = parseRateLimitHeaders(event.headers, provider);
    // Only update if we got meaningful data
    if (newInfo.remaining !== null || newInfo.limit !== null) {
      rateLimit = newInfo;
    }
  });
}