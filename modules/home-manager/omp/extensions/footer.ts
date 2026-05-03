import type { AssistantMessage } from "@oh-my-pi/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

// --- Rate limit state ---
interface RateLimitInfo {
  remaining: number | null;
  limit: number | null;
  resetAt: number | null;  // Unix timestamp in seconds
  provider: string;
}

interface RateLimitDimension {
  remaining: number | null;
  limit: number | null;
  resetAt: number | null;
}

interface OpenCodeGoRateLimit {
  requests: RateLimitDimension;
  tokens: RateLimitDimension;
}

let rateLimit: RateLimitInfo = {
  remaining: null,
  limit: null,
  resetAt: null,
  provider: "",
};

let ocGoRateLimit: OpenCodeGoRateLimit | null = null;

function fmtCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return `${n}`;
}

function ctxBar(pct: number): string {
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

function fmtResetTime(resetAt: number | null): string | null {
  if (resetAt === null) return null;
  const secondsLeft = Math.max(0, resetAt - Math.floor(Date.now() / 1000));
  if (secondsLeft <= 0) return null;
  if (secondsLeft >= 3600) return `${Math.ceil(secondsLeft / 3600)}h`;
  if (secondsLeft >= 60) return `${Math.ceil(secondsLeft / 60)}m`;
  return `${secondsLeft}s`;
}

function parseResetTimestamp(resetStr: string | undefined): number | null {
  if (!resetStr) return null;
  const parsed = parseFloat(resetStr);
  if (isNaN(parsed)) return null;
  if (parsed > 1577836800) return parsed;
  return Math.floor(Date.now() / 1000) + parsed;
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

  const resetTime = fmtResetTime(info.resetAt);
  if (resetTime) {
    parts.push(`↺${resetTime}`);
  }

  return parts.join(" ");
}

function fmtOcGoRateLimit(info: OpenCodeGoRateLimit): string | null {
  const { requests, tokens } = info;
  const reqHasData = requests.remaining !== null || requests.limit !== null;
  const tokHasData = tokens.remaining !== null || tokens.limit !== null;
  if (!reqHasData && !tokHasData) return null;

  const parts: string[] = [];

  if (reqHasData) {
    if (requests.remaining !== null && requests.limit !== null) {
      parts.push(`${requests.remaining}/${requests.limit}req`);
    } else if (requests.remaining !== null) {
      parts.push(`${requests.remaining}req left`);
    } else if (requests.limit !== null) {
      parts.push(`${requests.limit}req limit`);
    }
  }

  if (tokHasData) {
    if (tokens.remaining !== null && tokens.limit !== null) {
      parts.push(`${fmtCount(tokens.remaining)}/${fmtCount(tokens.limit)}tok`);
    } else if (tokens.remaining !== null) {
      parts.push(`${fmtCount(tokens.remaining)}tok left`);
    } else if (tokens.limit !== null) {
      parts.push(`${fmtCount(tokens.limit)}tok limit`);
    }
  }

  const resetTime = fmtResetTime(requests.resetAt ?? tokens.resetAt);
  if (resetTime) {
    parts.push(`↺${resetTime}`);
  }

  return parts.join(" · ");
}

function parseRateLimitHeaders(headers: Record<string, string>, provider: string): RateLimitInfo {
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
    const parsed = parseFloat(resetStr);
    if (!isNaN(parsed)) {
      if (parsed > 1577836800) {
        resetAt = parsed;
      } else {
        resetAt = Math.floor(Date.now() / 1000) + parsed;
      }
    }
  }

  return { remaining, limit, resetAt, provider };
}

function parseOpenCodeGoHeaders(headers: Record<string, string>): OpenCodeGoRateLimit | null {
  const get = (name: string): string | undefined =>
    headers[name] ?? headers[name.toLowerCase()] ?? undefined;

  const reqRemaining = parseInt(get("x-ratelimit-remaining-requests") ?? "", 10);
  const reqLimit = parseInt(get("x-ratelimit-limit-requests") ?? "", 10);
  const reqReset = parseResetTimestamp(get("x-ratelimit-reset-requests"));
  const tokRemaining = parseInt(get("x-ratelimit-remaining-tokens") ?? "", 10);
  const tokLimit = parseInt(get("x-ratelimit-limit-tokens") ?? "", 10);
  const tokReset = parseResetTimestamp(get("x-ratelimit-reset-tokens"));

  const reqHasData = !isNaN(reqRemaining) || !isNaN(reqLimit);
  const tokHasData = !isNaN(tokRemaining) || !isNaN(tokLimit);

  if (!reqHasData && !tokHasData) return null;

  return {
    requests: {
      remaining: isNaN(reqRemaining) ? null : reqRemaining,
      limit: isNaN(reqLimit) ? null : reqLimit,
      resetAt: reqReset,
    },
    tokens: {
      remaining: isNaN(tokRemaining) ? null : tokRemaining,
      limit: isNaN(tokLimit) ? null : tokLimit,
      resetAt: tokReset,
    },
  };
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

        const leftParts = [theme.fg("accent", cwdName)];
        if (branch) leftParts.push(theme.fg("muted", branch));
        if (preset) leftParts.push(theme.fg("dim", `[${preset}]`));
        const left = leftParts.join("  ");

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

        // Show OpenCode Go rate limits (requests + tokens) when available,
        // otherwise fall back to generic rate limit display
        const rlText = ocGoRateLimit
          ? fmtOcGoRateLimit(ocGoRateLimit)
          : fmtRateLimit(rateLimit);
        if (rlText) {
          rightParts.push(theme.fg("dim", `ℹ${rlText}`));
        }

        const right = rightParts.join("  ");
        const pad = " ".repeat(Math.max(1, width - pi.pi.visibleWidth(left) - pi.pi.visibleWidth(right)));

        return [pi.pi.truncateToWidth(`${left}${pad}${right}`, width)];
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

  pi.on("after_provider_response", async (event, ctx) => {
    const provider = ctx.model?.provider ?? "unknown";

    // Parse generic rate limit headers (all providers)
    const newInfo = parseRateLimitHeaders(event.headers, provider);
    if (newInfo.remaining !== null || newInfo.limit !== null) {
      rateLimit = newInfo;
    }

    // Parse OpenCode Go-specific rate limit headers (requests + tokens)
    if (provider === "opencode-go") {
      const ocGo = parseOpenCodeGoHeaders(event.headers);
      if (ocGo) {
        ocGoRateLimit = ocGo;
      }
    } else {
      // Clear OpenCode Go data when switching away from that provider
      ocGoRateLimit = null;
    }
  });
}