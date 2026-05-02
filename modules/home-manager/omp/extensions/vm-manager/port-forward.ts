import { join } from "node:path";
import { homedir } from "node:os";
import { spawn, type ChildProcess } from "node:child_process";

interface ForwardedPort {
  port: number;
  process: ChildProcess | null;
  label: string;
}

const forwardedPorts: Map<number, ForwardedPort> = new Map();

export async function startStaticForwards(
  config: { static: { from: number; label: string }[] } | undefined,
  _sshTarget: string,
): Promise<void> {
  if (!config || !config.static) return;
  for (const entry of config.static) {
    await forwardPort(entry.from, entry.from, entry.label);
  }
}

export async function forwardPort(
  localPort: number,
  remotePort: number,
  label: string,
): Promise<void> {
  if (forwardedPorts.has(localPort)) return;

  // Run SSH from the host directly against the lima VM's SSH target.
  // lima writes the VM's SSH config to ~/.lima/<name>/ssh.config
  const sshConfig = join(homedir(), ".lima", "pi-vm", "ssh.config");

  const proc = spawn(
    "ssh",
    ["-F", sshConfig, "-N", "-L", `${localPort}:localhost:${remotePort}`, "lima-pi-vm"],
    { stdio: "ignore" },
  );

  forwardedPorts.set(localPort, { port: localPort, process: proc, label });
}

export async function stopAllForwards(): Promise<void> {
  for (const [port, entry] of forwardedPorts) {
    if (entry.process) entry.process.kill();
  }
  forwardedPorts.clear();
}
