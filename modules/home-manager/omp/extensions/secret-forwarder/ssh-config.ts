import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { basename, resolve as pathResolve } from "node:path";
import { homedir } from "node:os";
import type { SecretForwarderConfig } from "./config.js";

const VAR_NAME_RE = /^[A-Z_][A-Z0-9_]*$/;

function sq(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

const SOURCE_ALLOWLIST = [".kube/", ".config/", ".omp/"];

function isAllowedSource(expanded: string, home: string): boolean {
  const resolved = pathResolve(expanded);
  return SOURCE_ALLOWLIST.some((prefix) => resolved.startsWith(pathResolve(home, prefix)));
}

function spawnAsync(cmd: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "ignore", "pipe"] });
    const err: Buffer[] = [];
    child.stderr.on("data", (d) => err.push(d));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(`${cmd} failed (${code}): ${Buffer.concat(err)}`));
      else resolve();
    });
  });
}

function spawnWithStdin(cmd: string, args: string[], data: Buffer): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["pipe", "ignore", "pipe"] });
    const err: Buffer[] = [];
    child.stderr.on("data", (d) => err.push(d));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(`${cmd} failed (${code}): ${Buffer.concat(err)}`));
      else resolve();
    });
    child.stdin.write(data);
    child.stdin.end();
  });
}

export function buildSshEnvArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];
  for (const varName of config.envVars) {
    if (!VAR_NAME_RE.test(varName)) {
      console.warn(`Secret Forwarder: skipping invalid env var name: ${varName}`);
      continue;
    }
    const value = process.env[varName];
    if (value !== undefined) {
      args.push("-o", `SetEnv=${varName}=${value}`);
    }
  }
  return args;
}

export function buildSshSocketArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];
  const home = homedir();
  for (const socketPath of config.sockets) {
    const expanded = socketPath.replace(/^~\//, home + "/");
    if (/['"\\]/.test(expanded)) {
      console.warn(`Secret Forwarder: blocking socket path with shell metacharacters: ${socketPath}`);
      continue;
    }
    if (/agent(\.sock)?$/.test(expanded) || (expanded.includes("ssh") && expanded.includes("agent"))) {
      console.warn(`Secret Forwarder: blocking SSH agent socket forwarding: ${socketPath}`);
      continue;
    }
    if (!existsSync(expanded)) continue;
    args.push("-R", `${expanded}:${expanded}`);
  }
  return args;
}

export function buildSshPortForwardArgs(config: SecretForwarderConfig): string[] {
  const args: string[] = [];
  for (const entry of config.forwardPorts.static) {
    args.push("-L", `${entry.from}:localhost:${entry.from}`);
  }
  return args;
}
export function getForwardedEnvRecord(config: SecretForwarderConfig): Record<string, string> {
  const result: Record<string, string> = {};
  for (const varName of config.envVars) {
    if (!VAR_NAME_RE.test(varName)) continue;
    const value = process.env[varName];
    if (value !== undefined) result[varName] = value;
  }
  return result;
}

export async function copyFilesToVm(
  config: SecretForwarderConfig,
  vmName: string,
): Promise<void> {
  const home = homedir();
  for (const filePath of config.files) {
    const expanded = filePath.replace(/^~\//, home + "/");
    const resolved = pathResolve(expanded);

    if (!isAllowedSource(resolved, home)) {
      console.warn(`Secret Forwarder: blocking file outside allowlist: ${filePath}`);
      continue;
    }
    if (!existsSync(resolved)) continue;

    const base = basename(resolved);
    const destPath = `/home/user/.omp/secrets/${base}`;
    const content = readFileSync(resolved);

    await spawnAsync("limactl", ["shell", vmName, "--", "mkdir", "-p", "/home/user/.omp/secrets"]);
    await spawnWithStdin("limactl", ["shell", vmName, "--", "bash", "-c", `cat > ${sq(destPath)}`], content);
    await spawnAsync("limactl", ["shell", vmName, "--", "chmod", "600", destPath]);
  }
}
