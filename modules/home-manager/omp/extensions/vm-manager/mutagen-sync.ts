import { spawn } from "node:child_process";

const SESSION_NAME = "pi-vm-sync";

function runMutagen(mutagenBin: string, args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(mutagenBin, args, { stdio: ["ignore", "pipe", "pipe"] });
    const out: Buffer[] = [];
    const err: Buffer[] = [];
    child.stdout.on("data", (d) => out.push(d));
    child.stderr.on("data", (d) => err.push(d));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) reject(new Error(`mutagen ${args[0]} failed (${code}): ${Buffer.concat(err)}`));
      else resolve(Buffer.concat(out).toString());
    });
  });
}

export async function startSync(localPath: string, mutagenBin: string): Promise<void> {
  try {
    const out = await runMutagen(mutagenBin, ["sync", "list", SESSION_NAME]);
    if (out.includes(SESSION_NAME)) {
      await runMutagen(mutagenBin, ["sync", "resume", SESSION_NAME]);
      return;
    }
  } catch {}

  await runMutagen(mutagenBin, [
    "sync", "create",
    localPath,
    "lima-pi-vm:/home/user/project",
    "--name", SESSION_NAME,
    "--ignore", ".git/hooks/**",
    "--ignore", ".git/config",
    "--ignore", "**/.env",
    "--ignore", "**/.envrc",
  ]);
}

export async function stopSync(mutagenBin: string): Promise<void> {
  try {
    await runMutagen(mutagenBin, ["sync", "terminate", SESSION_NAME]);
  } catch {
    // Ignore errors if session doesn't exist
  }
}

export async function checkSyncStatus(
  mutagenBin: string,
): Promise<"idle" | "syncing" | "conflict" | "error" | "none"> {
  try {
    const out = await runMutagen(mutagenBin, ["sync", "list", SESSION_NAME]);
    if (out.includes("Conflicts")) return "conflict";
    if (out.includes("Scanning") || out.includes("Syncing")) return "syncing";
    if (out.includes("Watching")) return "idle";
    return "none";
  } catch {
    return "none";
  }
}
