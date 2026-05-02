import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir } from "@oh-my-pi/pi-utils";

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
    auto: true,
    static: [],
    ranges: [],
  },
};

export function loadConfig(): SecretForwarderConfig {
  const configPath = join(getAgentDir(), "extensions", "secret-forwarder.json");
  if (!existsSync(configPath)) return DEFAULT_CONFIG;
  try {
    const raw = JSON.parse(readFileSync(configPath, "utf-8"));
    return { ...DEFAULT_CONFIG, ...raw };
  } catch {
    return DEFAULT_CONFIG;
  }
}
