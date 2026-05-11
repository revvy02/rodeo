// End-to-end CLI test helpers. Unlike tests-new/api/ which drives the TS
// RodeoClient library, tests-new/cli/ spawns `rodeo` as a subprocess and
// asserts on its stdout/stderr/exit. `makeCliRunFn` bridges those subprocess
// invocations into the RunFn signature used by tests-new/utils/executionTests.ts
// so the shared factories can run against the CLI unchanged.

import type { Subprocess } from "bun";
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
  const client = new RodeoClient(`http://localhost:${port}`);
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
  const client = new RodeoClient(`http://localhost:${port}`);
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

    return {
      ok: proc.exitCode === 0,
      output,
      exitCode: proc.exitCode ?? -1,
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
