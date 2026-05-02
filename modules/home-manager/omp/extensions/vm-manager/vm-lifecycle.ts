import { exec } from "node:child_process";
import { promisify } from "node:util";
import { join } from "node:path";
import { getAgentDir } from "@oh-my-pi/pi-utils";
import type { VmManagerConfig } from "./config.js";

const execAsync = promisify(exec);

const VM_NAME = "pi-vm";

export interface VmStatus {
  running: boolean;
  name: string;
  sshTarget: string;
}

export async function checkVmStatus(): Promise<VmStatus> {
  try {
    const { stdout } = await execAsync("limactl list --json");
    const vms = stdout
      .trim()
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line));
    const vm = vms.find((v: any) => v.name === VM_NAME);
    if (vm && vm.status === "Running") {
      return { running: true, name: VM_NAME, sshTarget: `lima-${VM_NAME}` };
    }
    return { running: false, name: VM_NAME, sshTarget: "" };
  } catch {
    return { running: false, name: VM_NAME, sshTarget: "" };
  }
}

export async function startVm(config: VmManagerConfig): Promise<VmStatus> {
  const status = await checkVmStatus();
  if (status.running) return status;

  const templatePath = join(
    getAgentDir(),
    "extensions",
    "vm-manager",
    "lima-template.yaml",
  );
  await execAsync(
    `limactl start --name=${VM_NAME} --tty=false ${templatePath}`,
  );
  await waitForSsh();
  return checkVmStatus();
}

export async function stopVm(): Promise<void> {
  const status = await checkVmStatus();
  if (!status.running) return;
  await execAsync(`limactl stop ${VM_NAME}`);
  await execAsync(`limactl delete ${VM_NAME}`);
}

export async function waitForSsh(
  maxRetries = 30,
  delayMs = 1000,
): Promise<void> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      await execAsync(`limactl shell ${VM_NAME} echo ok`, {
        timeout: 5000,
      });
      return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw new Error(`VM SSH not ready after ${maxRetries} retries`);
}

export async function runInVm(
  command: string,
  _config: VmManagerConfig,
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  const wrappedCommand = `cd /home/user/project && flox activate -- ${command}`;
  try {
    const { stdout, stderr } = await execAsync(
      `limactl shell ${VM_NAME} /bin/bash -c ${JSON.stringify(wrappedCommand)}`,
      { timeout: 120000 },
    );
    return { stdout, stderr, exitCode: 0 };
  } catch (err: any) {
    return {
      stdout: err.stdout ?? "",
      stderr: err.stderr ?? "",
      exitCode: err.code ?? 1,
    };
  }
}
