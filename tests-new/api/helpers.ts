import { beforeAll, afterAll } from "bun:test";
import { RodeoClient, type Vm, type Studio, type StudioBackend } from "../../rodeo-client-ts/src/index.js";
import type { RunCodeOpts, RunResult } from "../../rodeo-client-ts/src/run.js";

let nextPort = 46400;

export type StudioCtx = {
  client: RodeoClient;
  studio: Studio;
  editVm: Vm;
  port: number;
};

export function setupStudio(port: number = nextPort++): StudioCtx {
  const ctx = { port } as StudioCtx;
  let serverProc: ReturnType<typeof Bun.spawn> | null = null;

  beforeAll(async () => {
    serverProc = Bun.spawn(
      ["rodeo", "serve", "--port", String(port), "--ppid", String(process.pid)],
      { stderr: "inherit" },
    );
    ctx.client = await RodeoClient.connect(`http://localhost:${port}`);
    const rbxStudio = await ctx.client.getLocalStudio();
    ctx.studio = await rbxStudio.open({ background: true });
    ctx.editVm = ctx.studio.editVm;
  });

  afterAll(async () => {
    await ctx.studio?.close();
    serverProc?.kill();
    await serverProc?.exited;
  });

  return ctx;
}

export type BackendCtx = {
  client: RodeoClient;
  backend: StudioBackend;
  port: number;
};

// Spawns `rodeo serve` and exposes the local StudioBackend without opening an
// edit Studio. Use for tests that need to open their own Studio with
// non-default options (e.g. profile:true), where setupStudio's extra Studio
// process would just be waste.
export function setupBackend(port: number = nextPort++): BackendCtx {
  const ctx = { port } as BackendCtx;
  let serverProc: ReturnType<typeof Bun.spawn> | null = null;

  beforeAll(async () => {
    serverProc = Bun.spawn(
      ["rodeo", "serve", "--port", String(port), "--ppid", String(process.pid)],
      { stderr: "inherit" },
    );
    ctx.client = await RodeoClient.connect(`http://localhost:${port}`);
    ctx.backend = await ctx.client.getLocalStudio();
  });

  afterAll(async () => {
    serverProc?.kill();
    await serverProc?.exited;
  });

  return ctx;
}

// Explicit-lifecycle Studio handle. Unlike setupStudio above, the caller
// registers the hooks themselves so the lifecycle is visible at the call-site:
//
//   describe("my suite", () => {
//     const studio = studioHandle(46600);
//     beforeAll(studio.spawn);
//     afterAll(studio.close);
//     describe("...", () => factory((o) => studio.ctx.editVm.runCode(o)));
//   });
//
// Use this when one Studio should back multiple nested describes (the shared
// pattern in api/pkg.test.ts and api/runtime.test.ts); use setupStudio when one
// Studio per file is fine.
export type StudioHandle = {
  ctx: StudioCtx;
  spawn: () => Promise<void>;
  close: () => Promise<void>;
};

// RunFn-shaped wrapper around `ctx.editVm.runCode`. Lets the shared factories
// in tests-new/utils/executionTests.ts run end-to-end against the API path
// the same way `makeCliRunFn` does for the CLI subprocess.
export function makeApiRunFn(ctx: StudioCtx): (opts: RunCodeOpts) => Promise<RunResult> {
  return (opts) => ctx.editVm.runCode(opts);
}

export function studioHandle(port: number): StudioHandle {
  const ctx = { port } as StudioCtx;
  let serverProc: ReturnType<typeof Bun.spawn> | null = null;
  return {
    ctx,
    spawn: async () => {
      serverProc = Bun.spawn(
        ["rodeo", "serve", "--port", String(port), "--ppid", String(process.pid)],
        { stderr: "inherit" },
      );
      ctx.client = await RodeoClient.connect(`http://localhost:${port}`);
      const rbxStudio = await ctx.client.getLocalStudio();
      ctx.studio = await rbxStudio.open({ background: true });
      ctx.editVm = ctx.studio.editVm;
    },
    close: async () => {
      await ctx.studio?.close();
      serverProc?.kill();
      await serverProc?.exited;
    },
  };
}
