import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export interface PortForward {
  from: number;
  label: string;
}

export interface PortRange {
  start: number;
  end: number;
  label: string;
}

export interface SecretForwarderConfig {
  envVars: string[];
  sockets: string[];
  files: string[];
  forwardPorts: {
    auto: boolean;
    static: PortForward[];
    ranges: PortRange[];
  };
}

const DEFAULT_CONFIG: SecretForwarderConfig = {
  envVars: [],
  sockets: [],
  files: [],
  forwardPorts: {
    auto: false,
    static: [],
    ranges: [],
  },
};

export function loadConfig(agentDir: string): SecretForwarderConfig {
  const configPath = join(agentDir, "extensions", "secret-forwarder.json");
  if (!existsSync(configPath)) return DEFAULT_CONFIG;
  try {
    const raw = JSON.parse(readFileSync(configPath, "utf-8"));
    return { ...DEFAULT_CONFIG, ...raw };
  } catch {
    return DEFAULT_CONFIG;
  }
}
