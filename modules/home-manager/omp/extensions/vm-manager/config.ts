import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir } from "@oh-my-pi/pi-utils";

export interface VmManagerConfig {
  enabled: boolean;
  vmType: "vz" | "qemu";
  cpus: number;
  memory: string;
  disk: string;
  image: string;
  nixStorePath: string;
  mutagenBin: string;
  projectSyncPath: string;
  forwardPorts?: {
    auto: boolean;
    static: { from: number; label: string }[];
    ranges: { start: number; end: number; label: string }[];
  };
}

const GLOBAL_ONLY = new Set(["mutagenBin", "nixStorePath", "image"]);
const DEFAULT_CONFIG: VmManagerConfig = {
  enabled: true,
  vmType: "vz",
  cpus: 4,
  memory: "8GiB",
  disk: "50GiB",
  image: "https://cloud-images.ubuntu.com/minimal/releases/24.04/release/ubuntu-24.04-minimal-cloudimg-arm64.img",
  nixStorePath: "~/.omp/agent/vm/nix-store",
  mutagenBin: "mutagen",
  projectSyncPath: ".",
  forwardPorts: {
    auto: false,
    static: [],
    ranges: [],
  },
};

function loadJsonFile(path: string): Partial<VmManagerConfig> | undefined {
  if (!existsSync(path)) return undefined;
  try {
    return JSON.parse(readFileSync(path, "utf-8")) as Partial<VmManagerConfig>;
  } catch {
    return undefined;
  }
}

function deepMerge<T extends Record<string, unknown>>(
  base: T,
  ...overlays: (Partial<T> | undefined)[]
): T {
  const result = { ...base };
  for (const overlay of overlays) {
    if (!overlay) continue;
    for (const [key, value] of Object.entries(overlay)) {
      if (value !== undefined && value !== null) {
        if (
          typeof value === "object" &&
          !Array.isArray(value) &&
          typeof result[key] === "object"
        ) {
          result[key] = deepMerge(
            result[key] as Record<string, unknown>,
            value as Record<string, unknown>,
          ) as T[Extract<keyof T, string>];
        } else {
          result[key] = value as T[Extract<keyof T, string>];
        }
      }
    }
  }
  return result;
}

export function loadConfig(cwd: string): VmManagerConfig {
  const globalPath = join(getAgentDir(), "extensions", "vm-manager.json");
  const projectPath = join(cwd, ".omp", "vm-manager.json");
  const projectConfig = loadJsonFile(projectPath);
  const { mutagenBin: _mb, nixStorePath: _nsp, image: _img, ...projectOverridable } = projectConfig ?? {};
  if (_mb !== undefined || _nsp !== undefined || _img !== undefined) {
    console.warn("vm-manager: global-only keys (mutagenBin, nixStorePath, image) in project config were ignored");
  }
  return deepMerge(DEFAULT_CONFIG, loadJsonFile(globalPath), projectOverridable);
}
