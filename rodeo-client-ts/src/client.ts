//! Thin JSON-RPC wrappers over `rodeo __spawn_canonical_client`.
//!
//! Public API is preserved 1:1 from the pre-daemon client so `tests-new/`
//! needs no changes. All Studio lifecycle / VM discovery / runCode streaming
//! logic lives in the `rodeo-client` Rust crate; this file is just handle
//! plumbing + a runCode-to-final-RunResult collector.

import { Daemon } from "./daemon.js";
import type { LogFilter, RunCodeOpts, RunResult } from "./run.js";

export type { LogFilter, RunCodeOpts, RunResult };

// ---------------------------------------------------------------------------
// Shape of daemon responses
// ---------------------------------------------------------------------------

type VmSnapshotDTO = {
  vmId: string;
  backendId: string;
  mode: string;
  dom: string;
  sessionGuid?: string | null;
  placeId: number;
  gameName: string;
  connected: boolean;
  activeRuns: number;
};

type StateSnapshotDTO = {
  vms: VmSnapshotDTO[];
};

type BackendInfoDTO = {
  id: string;
  kind: string;
  name: string;
};

type ProcessInfoDTO = Record<string, unknown>;

// ---------------------------------------------------------------------------
// Vm
// ---------------------------------------------------------------------------

export class Vm {
  readonly vmId: string;
  readonly backendId: string;
  readonly mode: string;
  readonly dom: string;
  readonly sessionGuid: string | undefined;
  readonly placeId: number;
  readonly gameName: string;
  readonly connected: boolean;
  readonly activeRuns: number;
  protected daemon: Daemon;

  constructor(snap: VmSnapshotDTO, daemon: Daemon) {
    this.vmId = snap.vmId;
    this.backendId = snap.backendId ?? "";
    this.mode = snap.mode ?? "";
    this.dom = snap.dom ?? "";
    this.sessionGuid = snap.sessionGuid ?? undefined;
    this.placeId = Number(snap.placeId ?? 0);
    this.gameName = snap.gameName ?? "";
    this.connected = snap.connected;
    this.activeRuns = snap.activeRuns;
    this.daemon = daemon;
  }

  async runCode(opts: RunCodeOpts): Promise<RunResult> {
    // Process source via rodeo __process_source (preserves old CLI-path
    // behavior: bundle + shims + ensure_return). The daemon takes the
    // already-processed script as `source`.
    const processed = processSource({ source: opts.source, file: opts.file, sourcemap: opts.sourcemap });

    const executionId = crypto.randomUUID();
    const profileDir = opts.profile !== undefined
      ? (opts.profile || `.rodeo/.temp/profiles/${executionId}`)
      : undefined;
    const logsDir = opts.logs !== undefined
      ? (opts.logs || `.rodeo/.temp/logs/${executionId}`)
      : undefined;

    // Client-allocated streamId: we register the callback BEFORE sending the
    // request, so notifications can arrive at any time (even before the
    // RPC response) without being lost. Matches the LSP progress-token pattern.
    const streamId = crypto.randomUUID();

    let bufferedOutput = "";
    let resolveRun!: (r: RunResult) => void;
    let rejectRun!: (e: Error) => void;
    const runPromise = new Promise<RunResult>((res, rej) => { resolveRun = res; rejectRun = rej; });

    this.daemon.registerStream(streamId, (method, params) => {
      if (method === "stream.data") {
        const kind = params.kind as string;
        // stdout and stderr are merged into the single `output` field of
        // RunResult — matches the pre-daemon client's behavior. Wrappers that
        // want them separated can key off `kind` via a custom subscriber.
        if (kind === "stdout" || kind === "stderr") {
          bufferedOutput += String(params.chunk ?? "");
        }
      } else if (method === "stream.done") {
        this.daemon.unregisterStream(streamId);
        const r = (params.result ?? {}) as {
          ok?: boolean;
          output?: string;
          exitCode?: number;
        };
        resolveRun({
          ok: r.ok ?? false,
          output: (r.output && r.output.length > 0) ? r.output : bufferedOutput,
          exitCode: r.exitCode ?? 0,
        });
      } else if (method === "stream.error") {
        this.daemon.unregisterStream(streamId);
        rejectRun(new Error(String(params.error ?? "run failed")));
      }
    });

    try {
      await this.daemon.request<{ streamId: string }>("vm.runCode", {
        vmId: this.vmId,
        streamId,
        source: processed.script,
        target: opts.target ?? null,
        showReturn: opts.showReturn ?? false,
        cacheRequires: opts.cacheRequires ?? false,
        verbose: opts.verbose ?? false,
        scriptArgs: opts.scriptArgs ?? [],
        profileDir: profileDir ?? null,
        logsDir: logsDir ?? null,
        returnFile: opts.returnFile ?? null,
        processName: opts.processName ?? null,
        instancePath: processed.instancePath ?? null,
        scriptPath: processed.scriptPath ?? null,
        logFilter: opts.logFilter ?? null,
      });
    } catch (e) {
      this.daemon.unregisterStream(streamId);
      throw e;
    }

    return await runPromise;
  }
}

// ---------------------------------------------------------------------------
// RodeoClient
// ---------------------------------------------------------------------------

export class RodeoClient {
  readonly daemon: Daemon;

  constructor(url: string) {
    const { host, port } = parseUrl(url);
    this.daemon = new Daemon(host, port);
  }

  /** Call this in afterAll / teardown to shut down the daemon subprocess. */
  async close(): Promise<void> {
    await this.daemon.shutdown();
  }

  // Health & state

  async isHealthy(): Promise<boolean> {
    try {
      return await this.daemon.request<boolean>("client.isHealthy");
    } catch {
      return false;
    }
  }

  async getState(): Promise<StateSnapshotDTO> {
    return await this.daemon.request<StateSnapshotDTO>("client.getState");
  }

  // Process management

  async listProcesses(): Promise<ProcessInfoDTO[]> {
    return await this.daemon.request<ProcessInfoDTO[]>("client.listProcesses");
  }

  async kill(processId: number): Promise<void> {
    await this.daemon.request<null>("client.kill", { processId });
  }

  // Backend discovery

  async listBackends(kind?: string): Promise<BackendInfoDTO[]> {
    return await this.daemon.request<BackendInfoDTO[]>("client.listBackends", kind ? { kind } : {});
  }

  async getLocalStudio(): Promise<StudioBackend> {
    const resp = await this.daemon.request<{ backendHandle: string; info: { id: string; name: string } }>("client.getLocalStudio");
    return new StudioBackend(resp.backendHandle, resp.info, this.daemon);
  }

  async getStudio(idOrName: string): Promise<StudioBackend> {
    const resp = await this.daemon.request<{ backendHandle: string; info: { id: string; name: string } }>("client.getStudio", { idOrName });
    return new StudioBackend(resp.backendHandle, resp.info, this.daemon);
  }

  // VM discovery

  async getVms(): Promise<Vm[]> {
    const state = await this.getState();
    return state.vms.map((s) => new Vm(s, this.daemon));
  }

  async getVm(vmId: string): Promise<Vm> {
    const vms = await this.getVms();
    const found = vms.find((v) => v.vmId === vmId);
    if (!found) throw new Error(`vm '${vmId}' not found`);
    return found;
  }
}

// ---------------------------------------------------------------------------
// StudioBackend / options
// ---------------------------------------------------------------------------

export type OpenPlaceOpts = {
  placeId: number;
  fflags?: string[];
  background?: boolean;
  profile?: boolean;
  logs?: string;
  noHud?: boolean;
  /** Studio process survives `studio.close()` and rodeo serve exit. Caller
   *  owns the OS lifecycle from there — the Studio is no longer in rodeo's
   *  managed set after close. */
  detached?: boolean;
};

export type OpenFileOpts = {
  fflags?: string[];
  background?: boolean;
  profile?: boolean;
  logs?: string;
  noHud?: boolean;
  detached?: boolean;
};

export type OpenOpts = {
  fflags?: string[];
  background?: boolean;
  profile?: boolean;
  logs?: string;
  noHud?: boolean;
  detached?: boolean;
};

export class StudioBackend {
  readonly id: string;
  readonly name: string;
  private handle: string;
  private daemon: Daemon;

  constructor(handle: string, info: { id: string; name: string }, daemon: Daemon) {
    this.handle = handle;
    this.id = info.id;
    this.name = info.name;
    this.daemon = daemon;
  }

  async open(opts: OpenOpts = {}): Promise<Studio> {
    return this.launch("studio.open", {
      backendHandle: this.handle,
      fflags: opts.fflags ?? [],
      background: opts.background ?? false,
      profile: opts.profile ?? false,
      logs: opts.logs,
      noHud: opts.noHud ?? false,
      detached: opts.detached ?? false,
    });
  }

  async openPlace(opts: OpenPlaceOpts): Promise<Studio> {
    return this.launch("studio.openPlace", {
      backendHandle: this.handle,
      placeId: opts.placeId,
      fflags: opts.fflags ?? [],
      background: opts.background ?? false,
      profile: opts.profile ?? false,
      logs: opts.logs,
      noHud: opts.noHud ?? false,
      detached: opts.detached ?? false,
    });
  }

  async openFile(path: string, opts: OpenFileOpts = {}): Promise<Studio> {
    return this.launch("studio.openFile", {
      backendHandle: this.handle,
      path,
      fflags: opts.fflags ?? [],
      background: opts.background ?? false,
      profile: opts.profile ?? false,
      logs: opts.logs,
      noHud: opts.noHud ?? false,
      detached: opts.detached ?? false,
    });
  }

  /** Launch an isolated multiplayer-test server. No edit Studio required —
   * the MP server is its own OS-isolated process with its own session_guid.
   * Returns a single Vm-shaped handle: server.runCode(...), server.connectClient(),
   * server.close(). */
  async startMultiplayerTest(opts: StartMultiplayerTestOpts = {}): Promise<MultiplayerTestServer> {
    const resp = await this.daemon.request<{ vmId: string; sessionGuid: string }>("backend.startMultiplayerTest", {
      backendHandle: this.handle,
      placeFile: opts.placeFile,
      placeId: opts.placeId,
      fflags: opts.fflags ?? [],
      profile: opts.profile ?? false,
      runId: opts.runId,
      noHud: opts.noHud ?? false,
    });
    const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
    const snap = state.vms.find((v) => v.vmId === resp.vmId);
    if (!snap) throw new Error(`server VM ${resp.vmId} not found`);
    return new MultiplayerTestServer(snap, this.daemon);
  }

  private async launch(method: string, params: Record<string, unknown>): Promise<Studio> {
    const resp = await this.daemon.request<{
      studioHandle: string;
      sessionGuid: string;
      editVmId: string;
    }>(method, params);
    const studio = new Studio(resp.studioHandle, resp.sessionGuid, this.id, this.daemon);
    // Populate editVm by querying VMs — the daemon guaranteed it's connected.
    const vms = await studio.getVms();
    const editVm = vms.find((v) => v.vmId === resp.editVmId);
    if (!editVm) {
      throw new Error(`edit VM ${resp.editVmId} not found in studio ${resp.studioHandle}`);
    }
    studio.editVm = editVm;
    return studio;
  }
}

// ---------------------------------------------------------------------------
// Studio
// ---------------------------------------------------------------------------

export type StartMultiplayerTestOpts = {
  placeFile?: string;
  placeId?: number;
  fflags?: string[];
  profile?: boolean;
  runId?: string;
  noHud?: boolean;
};

export class Studio {
  readonly sessionGuid: string;
  readonly backendId: string;
  private handle: string;
  private daemon: Daemon;

  editVm!: Vm;
  serverVm: Vm | null = null;
  clientVm: Vm | null = null;

  constructor(handle: string, sessionGuid: string, backendId: string, daemon: Daemon) {
    this.handle = handle;
    this.sessionGuid = sessionGuid;
    this.backendId = backendId;
    this.daemon = daemon;
  }

  /** Poll master-wide VMs for a connected VM matching `pred`. Local polling —
   * the daemon doesn't currently expose a wait-for-vm RPC because only open /
   * setMode / startMultiplayerTest need it, and they already block in the
   * daemon until their target VM is connected. */
  async waitForVm(pred: (vm: Vm) => boolean, timeoutMs = 60_000): Promise<Vm> {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
      const match = state.vms.map((s) => new Vm(s, this.daemon)).find((v) => v.connected && pred(v));
      if (match) return match;
      await sleep(200);
    }
    throw new Error("timed out waiting for VM to register");
  }

  async setMode(mode: string): Promise<void> {
    const resp = await this.daemon.request<{
      serverVmId?: string | null;
      clientVmId?: string | null;
    }>("studio.setMode", { studioHandle: this.handle, mode });

    if (mode === "edit") {
      this.serverVm = null;
      this.clientVm = null;
      return;
    }

    // Look up VM objects by ID from state.
    const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
    const byId = (id: string | null | undefined) =>
      id ? state.vms.filter((v) => v.vmId === id).map((s) => new Vm(s, this.daemon))[0] ?? null : null;

    this.serverVm = byId(resp.serverVmId);
    this.clientVm = (mode === "test" || mode === "play") ? byId(resp.clientVmId) : null;
  }

  async getMode(): Promise<string> {
    return await this.daemon.request<string>("studio.getMode", { studioHandle: this.handle });
  }

  async save(): Promise<{ saved: boolean; path?: string; error?: string }> {
    return await this.daemon.request<{ saved: boolean; path?: string; error?: string }>(
      "studio.save", { studioHandle: this.handle },
    );
  }

  async close(): Promise<void> {
    await this.daemon.request<null>("studio.close", { studioHandle: this.handle });
  }

  async getVms(): Promise<Vm[]> {
    const vms = await this.daemon.request<VmSnapshotDTO[]>("studio.getVms", { studioHandle: this.handle });
    return vms.map((s) => new Vm(s, this.daemon));
  }
}

// ---------------------------------------------------------------------------
// MultiplayerTestServer / MultiplayerTestClient — Vm-with-extras. Same data
// plane (.runCode, .vmId, ...) as any Vm, plus session-lifecycle methods
// keyed by this VM's vmId (resolved server-side via the wrapper held in
// daemon state).
// ---------------------------------------------------------------------------

export class MultiplayerTestServer extends Vm {
  async connectClient(): Promise<MultiplayerTestClient> {
    const resp = await this.daemon.request<{ vmId: string }>(
      "vm.connectClient", { vmId: this.vmId },
    );
    const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
    const snap = state.vms.find((v) => v.vmId === resp.vmId);
    if (!snap) throw new Error(`client VM ${resp.vmId} not found`);
    return new MultiplayerTestClient(snap, this.daemon);
  }

  async close(): Promise<void> {
    await this.daemon.request<null>("vm.closeServer", { vmId: this.vmId });
  }
}

export class MultiplayerTestClient extends Vm {
  async disconnect(): Promise<void> {
    await this.daemon.request<null>("vm.disconnectClient", { vmId: this.vmId });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function parseUrl(url: string): { host: string; port: number } {
  // Accept "http://host:port" or "host:port".
  const clean = url.replace(/^https?:\/\//, "");
  const [host, portStr] = clean.split(":");
  const port = parseInt(portStr ?? "", 10);
  if (!host || !portStr || Number.isNaN(port)) {
    throw new Error(`invalid url for RodeoClient: ${url}`);
  }
  return { host, port };
}

type ProcessedSource = {
  script: string;
  scriptPath?: string;
  instancePath?: string;
};

function processSource(opts: { source?: string; file?: string; sourcemap?: string }): ProcessedSource {
  const args = ["__process_source"];
  if (opts.file) {
    args.push(opts.file);
    if (opts.sourcemap) args.push("--sourcemap", opts.sourcemap);
  } else if (opts.source) {
    args.push("--source", opts.source);
  } else {
    throw new Error("runCode requires either `source` or `file`");
  }
  const proc = Bun.spawnSync(["rodeo", ...args]);
  if (proc.exitCode !== 0) {
    const stderr = proc.stderr.toString().trim();
    throw new Error(`source processing failed: ${stderr}`);
  }
  return JSON.parse(proc.stdout.toString()) as ProcessedSource;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
