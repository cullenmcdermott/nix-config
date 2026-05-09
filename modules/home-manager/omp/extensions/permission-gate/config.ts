import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export interface PatternRules {
  autoPatterns: string[];
  promptPatterns: string[];
}

export interface PermissionGateConfig {
  enabled: boolean;
  rules: {
    bash: PatternRules;
    write: { mode: "auto" | "prompt" };
    edit: { mode: "auto" | "prompt" };
  };
}

const DEFAULT_CONFIG: PermissionGateConfig = {
  enabled: true,
  rules: {
    bash: {
      autoPatterns: [
        "git status*",
        "git log*",
        "git diff*",
        "git branch*",
        "kubectl get *",
        "kubectl describe *",
        "kubectl logs *",
        "rg *",
        "fd *",
        "cat *",
        "ls *",
        "find *",
        "head *",
        "tail *",
        "wc *",
        "file *",
        "which *",
        "flox list*",
        "flox search*",
      ],
      promptPatterns: [
        "kubectl apply *",
        "kubectl delete *",
        "kubectl patch *",
        "kubectl create *",
        "git push*",
        "rm *",
        "sudo *",
      ],
    },
    write: { mode: "prompt" },
    edit: { mode: "prompt" },
  },
};

/**
 * Simple glob matcher supporting `*` (any chars) and `?` (one char).
 */
export function minimatch(command: string, pattern: string): boolean {
  let pi = 0;
  let ci = 0;
  let starPi = -1;
  let starCi = -1;

  while (ci < command.length) {
    if (pi < pattern.length && (pattern[pi] === command[ci] || pattern[pi] === "?")) {
      pi++;
      ci++;
    } else if (pi < pattern.length && pattern[pi] === "*") {
      starPi = pi;
      starCi = ci;
      pi++;
    } else if (starPi !== -1) {
      pi = starPi + 1;
      starCi++;
      ci = starCi;
    } else {
      return false;
    }
  }

  while (pi < pattern.length && pattern[pi] === "*") {
    pi++;
  }

  return pi === pattern.length;
}

function readConfig(path: string): Partial<PermissionGateConfig> | undefined {
  if (!existsSync(path)) return undefined;
  try {
    const raw = readFileSync(path, "utf-8");
    return JSON.parse(raw) as Partial<PermissionGateConfig>;
  } catch {
    return undefined;
  }
}

function isRestrictedByGlobal(command: string, globalPromptPatterns: string[]): boolean {
  return globalPromptPatterns.some((pattern) => minimatch(command, pattern));
}

function mergePatternRules(
  base: PatternRules,
  overlay: Partial<PatternRules> | undefined,
  globalPromptPatterns: string[],
): PatternRules {
  const auto = new Set(base.autoPatterns);
  const prompt = new Set(base.promptPatterns);

  for (const p of overlay?.autoPatterns ?? []) {
    if (!isRestrictedByGlobal(p, globalPromptPatterns)) {
      auto.add(p);
    }
  }

  for (const p of overlay?.promptPatterns ?? []) {
    prompt.add(p);
  }

  return {
    autoPatterns: Array.from(auto),
    promptPatterns: Array.from(prompt),
  };
}

function deepMergeConfig(
  base: PermissionGateConfig,
  overlay: Partial<PermissionGateConfig>,
  globalPromptPatterns: string[],
): PermissionGateConfig {
  return {
    enabled: overlay.enabled ?? base.enabled,
    rules: {
      bash: mergePatternRules(base.rules.bash, overlay.rules?.bash, globalPromptPatterns),
      write: { mode: overlay.rules?.write?.mode ?? base.rules.write.mode },
      edit: { mode: overlay.rules?.edit?.mode ?? base.rules.edit.mode },
    },
  };
}

export function loadConfig(cwd: string, agentDir: string): PermissionGateConfig {
  const globalPath = join(agentDir, "extensions", "permission-gate.json");
  const projectPath = join(cwd, ".omp", "permission-gate.json");

  const globalRaw = readConfig(globalPath);
  const projectRaw = readConfig(projectPath);

  const globalPromptPatterns = globalRaw?.rules?.bash?.promptPatterns ?? [];

  let config = DEFAULT_CONFIG;

  if (globalRaw) {
    config = deepMergeConfig(config, globalRaw, globalPromptPatterns);
  }

  if (projectRaw) {
    config = deepMergeConfig(config, projectRaw, globalPromptPatterns);
  }

  return config;
}

export function savePattern(
  cwd: string,
  toolName: string,
  pattern: string,
  list: "autoPatterns" | "promptPatterns",
): void {
  const projectPath = join(cwd, ".omp", "permission-gate.json");

  let projectConfig: Partial<PermissionGateConfig> = readConfig(projectPath) ?? {};

  if (!projectConfig.rules) {
    projectConfig.rules = { bash: { autoPatterns: [], promptPatterns: [] }, write: { mode: "prompt" }, edit: { mode: "prompt" } };
  }

  if (toolName === "bash") {
    if (!projectConfig.rules.bash) {
      projectConfig.rules.bash = { autoPatterns: [], promptPatterns: [] };
    }
    if (!projectConfig.rules.bash.autoPatterns) {
      projectConfig.rules.bash.autoPatterns = [];
    }
    if (!projectConfig.rules.bash.promptPatterns) {
      projectConfig.rules.bash.promptPatterns = [];
    }
    const arr = projectConfig.rules.bash[list];
    if (!arr.includes(pattern)) {
      arr.push(pattern);
    }
  } else if (toolName === "write" || toolName === "edit") {
    // list="autoPatterns" -> mode="auto", list="promptPatterns" -> mode="prompt"
    projectConfig.rules[toolName] = { mode: list === "autoPatterns" ? "auto" : "prompt" };
  }

  const dir = join(cwd, ".omp");
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  writeFileSync(projectPath, JSON.stringify(projectConfig, null, 2) + "\n");
}
