// End-to-end CLI test helpers. Unlike tests-new/api/ which drives the TS
// RodeoClient library, tests-new/cli/ spawns `rodeo` as a subprocess and
// asserts on its stdout/stderr/exit. `makeCliRunFn` bridges those subprocess
// invocations into the RunFn signature used by tests-new/utils/executionTests.ts
// so the shared factories can run against the CLI unchanged.

import type { Subprocess } from "bun";
import { existsSync, readFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { RodeoClient } from "../../rodeo-client-ts/src/index.js";
import type { RunCodeOpts, RunResult } from "../../rodeo-client-ts/src/run.js";

// Hard cap for any synchronous `rodeo ...` subprocess. Without a timeout, a
// crashed/hung Studio leaves Bun.spawnSync blocked forever — `bun test
// --timeout` can't cancel synchronous calls, so the whole suite stalls. Set
// it to match the suite's `--timeout` so the spawn returns at the same
// wall-clock the test would have failed at anyway.
const SUBPROCESS_TIMEOUT_MS = 60_000;

export type ProcResult = {
  ok: boolean;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export function runRodeo(args: string[], opts: { timeout?: number } = {}): ProcResult {
  const timeout = opts.timeout ?? SUBPROCESS_TIMEOUT_MS;
  const proc = Bun.spawnSync(["rodeo", ...args], { timeout });
  const stdout = proc.stdout.toString();
  let stderr = proc.stderr.toString();
  if (proc.signalCode) {
    stderr += `\n[runRodeo: killed after ${timeout}ms via ${proc.signalCode}]`;
  }
  return {
    ok: proc.exitCode === 0,
    stdout,
    stderr,
    exitCode: proc.exitCode ?? -1,
  };
}

// Cross-platform process matchers. Unix uses pgrep/pkill with `-f` (match the
// full command line); Windows has neither, so shell to PowerShell's CIM process
// query, whose `CommandLine` field gives the same match surface. `pattern` is a
// regex in both worlds (pgrep -f and PowerShell -match both take regex).
const IS_WINDOWS = process.platform === "win32";

/** True if any running process's command line matches `pattern`. */
export function processMatches(pattern: string): boolean {
  if (IS_WINDOWS) {
    const r = Bun.spawnSync([
      "powershell", "-NoProfile", "-Command",
      `@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match '${pattern}' }).Count`,
    ]);
    return parseInt(r.stdout.toString().trim() || "0", 10) > 0;
  }
  return Bun.spawnSync(["pgrep", "-f", pattern]).exitCode === 0;
}

/** Force-kill every process whose command line matches `pattern`. */
export function killMatching(pattern: string): void {
  if (IS_WINDOWS) {
    Bun.spawnSync([
      "powershell", "-NoProfile", "-Command",
      `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match '${pattern}' } | ` +
        `ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }`,
    ]);
    return;
  }
  Bun.spawnSync(["pkill", "-f", pattern]);
}

/** PIDs of processes whose command line matches `pattern`. */
export function pidsMatching(pattern: string): number[] {
  const r = IS_WINDOWS
    ? Bun.spawnSync([
        "powershell", "-NoProfile", "-Command",
        `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match '${pattern}' } | ForEach-Object { $_.ProcessId }`,
      ])
    : Bun.spawnSync(["pgrep", "-f", pattern]);
  return r.stdout.toString().split(/\s+/).map((s) => parseInt(s, 10)).filter((n) => n > 0);
}

/**
 * Wait for every pid in `pids` to exit, up to `timeoutMs`; returns true if all
 * are gone. This is EVENT-DRIVEN, not name-polling: Windows blocks on the
 * process handles via `Wait-Process` (woken the instant they exit, one call —
 * not a slow per-tick CIM query), and other platforms early-return off the
 * cheap native `process.kill(pid, 0)` liveness check. Empty `pids` ⇒ true.
 */
export async function waitForPidsGone(pids: number[], timeoutMs: number): Promise<boolean> {
  if (pids.length === 0) return true;
  if (IS_WINDOWS) {
    const sec = Math.max(1, Math.ceil(timeoutMs / 1000));
    const idList = pids.join(",");
    const r = Bun.spawnSync([
      "powershell", "-NoProfile", "-Command",
      `Wait-Process -Id ${idList} -Timeout ${sec} -ErrorAction SilentlyContinue; ` +
        `if (@(${idList}) | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }) { exit 1 } else { exit 0 }`,
    ]);
    return r.exitCode === 0;
  }
  const alive = () => pids.some((pid) => { try { process.kill(pid, 0); return true; } catch { return false; } });
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!alive()) return true;
    await Bun.sleep(200);
  }
  return !alive();
}

export type BackgroundProcess = {
  kill: () => void;
  exited: Promise<number>;
  pid: number;
};

// `rodeo run` / `rodeo serve` accept --ppid; we pass our pid so the subprocess
// self-exits when bun dies, and its --ppid chain tears down master + backends
// + Studio. Without this, Bun.spawn children survive bun and leak (macOS has
// no parent-death signal).
export function spawnBackground(args: string[]): BackgroundProcess {
  const proc = Bun.spawn(["rodeo", ...args, "--ppid", String(process.pid)], {
    stderr: "inherit",
    stdout: "inherit",
    stdin: "ignore",
  }) as Subprocess;
  return {
    pid: proc.pid,
    kill: () => proc.kill(),
    exited: proc.exited,
  };
}

// Polls the master for a process in the requested state (e.g. "running",
// "done"). Returns the first matching process ID, or null on timeout.
// Replaces tests/utils/waitForProcess.luau.
export async function waitForProcess(
  port: number,
  state: string,
  timeoutMs = 30_000,
): Promise<number | null> {
  const client = await RodeoClient.connect(`http://localhost:${port}`);
  const start = Date.now();
  try {
    while (Date.now() - start < timeoutMs) {
      const procs = await client.listProcesses().catch(() => []);
      for (const p of procs as Array<{ processId: number; state: string }>) {
        if (p.state === state) return p.processId;
      }
      await Bun.sleep(200);
    }
    return null;
  } finally {
    await client.close();
  }
}

// Waits until at least one connected VM shows up on the master. Used after
// spawnBackground(["run","--place",...]) to ensure Studio is ready before
// the first `rodeo run --source` call. Without this, parallel test files
// racing the studio-daemon's 4-slot pool can see `rodeo run` time out
// waiting for a VM.
export async function waitForVm(port: number, timeoutMs = 60_000): Promise<void> {
  const client = await RodeoClient.connect(`http://localhost:${port}`);
  const start = Date.now();
  try {
    while (Date.now() - start < timeoutMs) {
      const vms = await client.getVms().catch(() => []);
      if (vms.some((v) => v.connected)) return;
      await Bun.sleep(250);
    }
    throw new Error(`timed out waiting for VM on port ${port}`);
  } finally {
    await client.close();
  }
}

// Builds a RunFn backed by `rodeo run` subprocess. Lets the shared factories
// in tests-new/utils/executionTests.ts run end-to-end against the CLI binary.
export function makeCliRunFn(
  port: number,
  baseTarget?: string,
): (opts: RunCodeOpts) => Promise<RunResult> {
  return async (opts: RunCodeOpts): Promise<RunResult> => {
    const args: string[] = ["run", "--port", String(port)];

    if (opts.source !== undefined) args.push("--source", opts.source);
    if (opts.sourcemap !== undefined) args.push("--sourcemap", opts.sourcemap);
    if (opts.showReturn) args.push("--show-return");
    if (opts.cacheRequires) args.push("--cache-requires");

    // CLI subprocesses don't see the wire-level ExecutionDone, so to give
    // tests a `result.return` to assert against we shadow it via the same
    // `--return <path>` mechanism the CLI already supports: write to a temp
    // JSON file unless the caller already passed their own `returnFile`,
    // then parse it back into the JS `RunResult.return`. The temp file is
    // cleaned up regardless of the run outcome.
    let autoReturnFile: string | undefined;
    if (opts.returnFile === undefined) {
      autoReturnFile = join(tmpdir(), `rodeo-cli-return-${randomUUID()}.json`);
    }

    const target = opts.target ?? baseTarget;
    if (target !== undefined) args.push("--target", target);

    if (opts.logFilter) {
      if (opts.logFilter.enableWarn === false) args.push("--no-warn");
      if (opts.logFilter.enableError === false) args.push("--no-error");
      if (opts.logFilter.enableInfo === false) args.push("--no-info");
      if (opts.logFilter.enableOutput === false) args.push("--no-print");
      // enableLogs currently has no CLI toggle; factories that depend on it
      // should gate on --no-output as a combined disable. If a factory fails,
      // port the specific case inline rather than inventing a new flag.
      if (opts.logFilter.enableWarn === false &&
          opts.logFilter.enableError === false &&
          opts.logFilter.enableInfo === false &&
          opts.logFilter.enableOutput === false &&
          opts.logFilter.enableLogs === false) {
        args.push("--no-output");
      }
    }

    // --profile and --logs accept optional output dirs; the CLI writes
    // artifacts directly to those paths. Tests that need to inspect file
    // bytes read them from disk.
    if (opts.profile !== undefined) {
      args.push("--profile");
      if (opts.profile.length > 0) args.push(opts.profile);
    }
    if (opts.logs !== undefined) {
      args.push("--logs");
      if (opts.logs.length > 0) args.push(opts.logs);
    }

    if (opts.returnFile !== undefined) {
      args.push("--return", opts.returnFile);
    } else if (autoReturnFile !== undefined) {
      args.push("--return", autoReturnFile);
    }

    // File script goes positionally (matches `rodeo run script.luau`).
    if (opts.file !== undefined) args.push(opts.file);

    // scriptArgs is `last = true` in clap — passed after `--`.
    if (opts.scriptArgs && opts.scriptArgs.length > 0) {
      args.push("--", ...opts.scriptArgs);
    }

    const globalArgs: string[] = [];
    if (opts.verbose) globalArgs.push("--verbose");

    const proc = Bun.spawnSync(["rodeo", ...globalArgs, ...args], { timeout: SUBPROCESS_TIMEOUT_MS });
    const stdout = proc.stdout.toString();
    let stderr = proc.stderr.toString();
    if (proc.signalCode) {
      stderr += `\n[makeCliRunFn: killed after ${SUBPROCESS_TIMEOUT_MS}ms via ${proc.signalCode}]`;
    }

    // Merge stdout+stderr — matches Luau's `stdio = "tee"` which the factories
    // assert against. Ordering is approximate (each stream captured separately)
    // but case asserts contain substring matches, not line ordering.
    const output = stdout + stderr;

    // Read back the auto-allocated `--return <path>` JSON, parse it into
    // `result.return`, then delete the temp file. If the caller passed their
    // own returnFile we leave it alone — they manage that file themselves.
    let parsedReturn: unknown = undefined;
    if (autoReturnFile !== undefined && existsSync(autoReturnFile)) {
      try {
        const raw = readFileSync(autoReturnFile, "utf-8");
        if (raw.length > 0) parsedReturn = JSON.parse(raw);
      } catch {
        parsedReturn = undefined;
      }
      try { unlinkSync(autoReturnFile); } catch {}
    }

    return {
      ok: proc.exitCode === 0,
      output,
      exitCode: proc.exitCode ?? -1,
      return: parsedReturn,
    };
  };
}

// Explicit-lifecycle CLI Studio handle. Caller registers the hooks themselves:
//
//   describe("my suite", () => {
//     const cli = cliStudioHandle(46100);
//     beforeAll(cli.spawn);
//     afterAll(cli.close);
//     describe("...", () => factory(cli.runFn));
//   });
export type CliStudioHandle = {
  runFn: (opts: RunCodeOpts) => Promise<RunResult>;
  spawn: () => Promise<void>;
  close: () => Promise<void>;
};

export function cliStudioHandle(port: number): CliStudioHandle {
  let bg: BackgroundProcess | null = null;
  return {
    runFn: makeCliRunFn(port),
    spawn: async () => {
      bg = spawnBackground(["run", "--port", String(port), "--place"]);
      await waitForVm(port);
    },
    close: async () => {
      bg?.kill();
      await bg?.exited;
    },
  };
}
