import { exec } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import type { SecretForwarderConfig } from "./config.js";

const execAsync = promisify(exec);

export function buildSshEnvArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];
  if (config.envVars.length === 0) return args;

  const envPairs: string[] = [];
  for (const varName of config.envVars) {
    const value = process.env[varName];
    if (value !== undefined) {
      envPairs.push(`${varName}=${value}`);
    }
  }

  if (envPairs.length > 0) {
    args.push("-o", `SetEnv=${envPairs.join(",")}`);
  }

  return args;
}

export function buildSshSocketArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];
  const home = homedir();

  for (const socketPath of config.sockets) {
    const expanded = socketPath.replace(/^~\//, home + "/");
    if (existsSync(expanded)) {
      // -R forwards a remote socket to a local socket
      args.push("-R", `${expanded}:${expanded}`);
    }
  }

  return args;
}

export function buildSshPortForwardArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];

  for (const entry of config.forwardPorts.static) {
    // -L forwards a local port to a remote port
    args.push("-L", `${entry.from}:localhost:${entry.from}`);
  }

  return args;
}

export async function copyFilesToVm(
  config: SecretForwarderConfig,
  vmName: string,
): Promise<void> {
  const home = homedir();

  for (const filePath of config.files) {
    const expanded = filePath.replace(/^~\//, home + "/");
    if (existsSync(expanded)) {
      const content = readFileSync(expanded);
      const b64 = content.toString("base64");
      await execAsync(
        `limactl shell ${vmName} -- bash -c 'echo ${JSON.stringify(b64)} | base64 -d > ${expanded}'`,
      );
    }
  }
}
