import { exec } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

const SESSION_NAME = "pi-vm-sync";

export async function startSync(localPath: string, mutagenBin: string): Promise<void> {
  // Check if session already exists
  try {
    const { stdout } = await execAsync(`${mutagenBin} sync list ${SESSION_NAME}`);
    if (stdout.includes(SESSION_NAME)) {
      // Resume existing session
      await execAsync(`${mutagenBin} sync resume ${SESSION_NAME}`);
      return;
    }
  } catch {}

  // Create new sync session
  await execAsync(
    `${mutagenBin} sync create ${localPath} lima-pi-vm:/home/user/project ${SESSION_NAME}`,
    { timeout: 30000 },
  );
}

export async function stopSync(mutagenBin: string): Promise<void> {
  try {
    await execAsync(`${mutagenBin} sync terminate ${SESSION_NAME}`);
  } catch {
    // Ignore errors if session doesn't exist
  }
}

export async function checkSyncStatus(
  mutagenBin: string,
): Promise<"idle" | "syncing" | "conflict" | "error" | "none"> {
  try {
    const { stdout } = await execAsync(`${mutagenBin} sync list ${SESSION_NAME}`);
    if (stdout.includes("Conflicts")) return "conflict";
    if (stdout.includes("Scanning") || stdout.includes("Syncing")) return "syncing";
    if (stdout.includes("Watching")) return "idle";
    return "none";
  } catch {
    return "none";
  }
}
