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

  // Use SSH -L to forward local port to VM port
  const proc = spawn(
    "limactl",
    ["shell", "pi-vm", "--", "ssh", "-N", "-L", `${localPort}:localhost:${remotePort}`],
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
