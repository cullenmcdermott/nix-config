import { minimatch } from "./config.js";
import type { PermissionGateConfig, PatternRules } from "./config.js";

export type Classification = "auto" | "prompt";

const COMMAND_CHAINING_CHARS = /[;|&`$(){}[\]\n<>]/;

export function classifyBash(command: string, rules: PatternRules): Classification {
  // Security: commands with shell metacharacters always require confirmation
  if (COMMAND_CHAINING_CHARS.test(command)) return "prompt";

  // Check prompt patterns first — global restrictions take precedence over auto
  for (const pattern of rules.promptPatterns) {
    if (minimatch(command, pattern)) return "prompt";
  }

  for (const pattern of rules.autoPatterns) {
    if (minimatch(command, pattern)) return "auto";
  }

  return "prompt";
}

export function classifyTool(
  toolName: string,
  command: string | undefined,
  config: PermissionGateConfig,
): Classification {
  if (toolName === "read" || toolName === "search" || toolName === "find") {
    return "auto";
  }
  if (toolName === "write" || toolName === "edit") {
    return config.rules[toolName].mode === "auto" ? "auto" : "prompt";
  }
  if (toolName === "bash" && command) {
    return classifyBash(command, config.rules.bash);
  }
  return "prompt";
}
