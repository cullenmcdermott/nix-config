import { resolve as pathResolve, relative as pathRelative, join as pathJoin } from "node:path";
import { spawn } from "node:child_process";
import type {
  BashOperations,
  EditOperations,
  ReadOperations,
  WriteOperations,
} from "@oh-my-pi/pi-coding-agent";

const VM_NAME = "pi-vm";

const LOCAL_CWD = process.cwd();
const REMOTE_CWD = "/home/user/project";

function sq(s: string): string {
  // single-quote escape — JSON.stringify is unsafe; bash double-quotes expand $() and backticks
  return `'${s.replace(/'/g, "'\\''")}'`;
}

function toRemote(p: string): string {
  const abs = pathResolve(p);
  const rel = pathRelative(LOCAL_CWD, abs);
  if (rel.startsWith("..")) throw new Error(`Path traversal blocked: ${p}`);
  return pathJoin(REMOTE_CWD, rel);
}

function sshExec(command: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const child = spawn(
      "limactl",
      ["shell", VM_NAME, "bash", "-c", command],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    const chunks: Buffer[] = [];
    const errChunks: Buffer[] = [];
    child.stdout.on("data", (data) => chunks.push(data));
    child.stderr.on("data", (data) => errChunks.push(data));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(
          new Error(
            `SSH failed (${code}): ${Buffer.concat(errChunks).toString()}`,
          ),
        );
      } else {
        resolve(Buffer.concat(chunks));
      }
    });
  });
}

export function createRemoteReadOps(): ReadOperations {
  return {
    readFile: (p) => sshExec(`cat ${sq(toRemote(p))}`),
    access: (p) =>
      sshExec(`test -r ${sq(toRemote(p))}`).then(
        () => {},
        () => {},
      ),
    detectImageMimeType: async (p) => {
      try {
        const r = await sshExec(
          `file --mime-type -b ${sq(toRemote(p))}`,
        );
        const m = r.toString().trim();
        return ["image/jpeg", "image/png", "image/gif", "image/webp"].includes(m)
          ? m
          : null;
      } catch {
        return null;
      }
    },
  };
}

export function createRemoteWriteOps(): WriteOperations {
  return {
    writeFile: async (p, content) => {
      const b64 = Buffer.from(content).toString("base64");
      await sshExec(
        `echo ${sq(b64)} | base64 -d > ${sq(toRemote(p))}`,
      );
    },
    mkdir: (dir) =>
      sshExec(`mkdir -p ${sq(toRemote(dir))}`).then(() => {}),
  };
}

export function createRemoteEditOps(): EditOperations {
  const r = createRemoteReadOps();
  const w = createRemoteWriteOps();
  return { readFile: r.readFile, access: r.access, writeFile: w.writeFile };
}

export function createRemoteBashOps(): BashOperations {
  return {
    exec(command, cwd, { onData, signal, timeout }) {
      const remoteCwd = toRemote(cwd);
      const wrappedCommand = `cd ${sq(remoteCwd)} && flox activate -- ${sq(command)}`;
      return new Promise((resolve, reject) => {
        const child = spawn(
          "limactl",
          ["shell", VM_NAME, "bash", "-c", wrappedCommand],
          { stdio: ["ignore", "pipe", "pipe"], detached: true },
        );
        let timedOut = false;
        const timer = timeout
          ? setTimeout(() => {
              timedOut = true;
              child.kill("SIGKILL");
            }, timeout * 1000)
          : undefined;
        child.stdout.on("data", onData);
        child.stderr.on("data", onData);
        child.on("error", (e) => {
          if (timer) clearTimeout(timer);
          reject(e);
        });
        const onAbort = () => {
          try {
            process.kill(-child.pid!, "SIGKILL");
          } catch {
            child.kill("SIGKILL");
          }
        };
        signal?.addEventListener("abort", onAbort, { once: true });
        child.on("close", (code) => {
          if (timer) clearTimeout(timer);
          signal?.removeEventListener("abort", onAbort);
          if (signal?.aborted) reject(new Error("aborted"));
          else if (timedOut) reject(new Error(`timeout:${timeout}`));
          else resolve({ exitCode: code });
        });
      });
    },
  };
}
