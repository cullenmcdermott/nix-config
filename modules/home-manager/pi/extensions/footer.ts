import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

function fmtCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return `${n}`;
}

function fmtCtx(used: number, max: number): string {
  return `${Math.round((used / max) * 100)}%/${fmtCount(max)}`;
}

function shortModelName(model: string): string {
  return model
    .replace(/^claude-/, "")
    .replace(/^gpt-/, "gpt-")
    .replace(/^gemini-/, "gemini-");
}

function cleanStatus(status: string): string {
  return status.replace(/^preset:/, "").trim();
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

        const rightParts = [
          theme.fg("muted", model),
          theme.fg("dim", thinking),
        ];

        if (contextUsage && contextUsage.tokens > 0 && contextUsage.maxTokens > 0) {
          rightParts.push(theme.fg("accent", fmtCtx(contextUsage.tokens, contextUsage.maxTokens)));
        }

        if (inputTokens + outputTokens >= 1000) {
          rightParts.push(theme.fg("dim", `↑${fmtCount(inputTokens)} ↓${fmtCount(outputTokens)}`));
        }

        if (totalCost > 0) {
          rightParts.push(theme.fg("dim", `$${totalCost.toFixed(totalCost < 0.001 ? 4 : 3)}`));
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
}
