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
  clientName?: string | null;
};

// Minimal per-VM entry on a studio in the studio-first snapshot.
type StudioVmEntryDTO = {
  vmId: string;
  dom: string;
  clientName?: string | null;
};

type StudioDTO = {
  id: string;
  backendId: string;
  mcpStudioId?: string | null;
  name: string;
  placeId: number;
  active: boolean;
  status: string;
  mode: string;
  vms: StudioVmEntryDTO[];
};

type StateSnapshotDTO = {
  backends?: BackendInfoDTO[];
  processes?: ProcessInfoDTO[];
  /** @deprecated still present for now; VM discovery reads `studios[].vms`. */
  vms: VmSnapshotDTO[];
  studios: StudioDTO[];
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
  readonly clientName: string | undefined;
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
    this.clientName = snap.clientName ?? undefined;
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
          returnValue?: string | null;
        };
        // The daemon ships the script's return value as a JSON string
        // (or null when the script didn't return anything). Parse here
        // so consumers can write `result.return` directly. Parse errors
        // are swallowed — we never throw at the consumer because the
        // script returned something non-JSON-encodable.
        let parsedReturn: unknown = undefined;
        if (typeof r.returnValue === "string" && r.returnValue.length > 0) {
          try {
            parsedReturn = JSON.parse(r.returnValue);
          } catch {
            parsedReturn = undefined;
          }
        }
        resolveRun({
          ok: r.ok ?? false,
          output: (r.output && r.output.length > 0) ? r.output : bufferedOutput,
          exitCode: r.exitCode ?? 0,
          return: parsedReturn,
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

export type ConnectOpts = {
  /** Max time to wait for the server to come up. Default 30000ms. */
  readyTimeoutMs?: number;
  /** Poll interval while waiting for the server. Default 200ms. */
  readyPollMs?: number;
};

export class RodeoClient {
  readonly daemon: Daemon;

  private constructor(url: string) {
    const { host, port } = parseUrl(url);
    this.daemon = new Daemon(host, port);
  }

  /** Connect to a running `rodeo serve` and block until it's healthy.
   *  Throws after `readyTimeoutMs` (default 30s) if the server never responds. */
  static async connect(url: string, opts: ConnectOpts = {}): Promise<RodeoClient> {
    const timeoutMs = opts.readyTimeoutMs ?? 30_000;
    const pollMs = opts.readyPollMs ?? 200;
    const client = new RodeoClient(url);
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      try {
        const ok = await client.daemon.request<boolean>("client.isHealthy");
        if (ok) return client;
      } catch {
        // server not up yet — retry until deadline
      }
      await new Promise((r) => setTimeout(r, pollMs));
    }
    await client.daemon.shutdown().catch(() => {});
    throw new Error(`RodeoClient.connect: timed out after ${timeoutMs}ms waiting for rodeo at ${url}`);
  }

  /** Call this in afterAll / teardown to shut down the daemon subprocess. */
  async close(): Promise<void> {
    await this.daemon.shutdown();
  }

  // State & discovery

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
    return vmsFromStudios(state, this.daemon);
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

export class Studio {
  readonly sessionGuid: string;
  readonly backendId: string;
  /** Opaque daemon handle for this Studio. Used by RPCs keyed on the Studio
   *  (setMode / getVms / startMultiplayerTest / save / close). */
  readonly studioHandle: string;
  private daemon: Daemon;

  editVm!: Vm;
  serverVm: Vm | null = null;
  clientVm: Vm | null = null;

  constructor(handle: string, sessionGuid: string, backendId: string, daemon: Daemon) {
    this.studioHandle = handle;
    this.sessionGuid = sessionGuid;
    this.backendId = backendId;
    this.daemon = daemon;
  }

  async setMode(mode: string): Promise<void> {
    const resp = await this.daemon.request<{
      serverVmId?: string | null;
      clientVmId?: string | null;
    }>("studio.setMode", { studioHandle: this.studioHandle, mode });

    if (mode === "edit") {
      this.serverVm = null;
      this.clientVm = null;
      return;
    }

    // Look up VM objects by ID from the studio-first snapshot.
    const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
    const byId = (id: string | null | undefined) => {
      if (!id) return null;
      const snap = findVmSnapshot(state, id);
      return snap ? new Vm(snap, this.daemon) : null;
    };

    this.serverVm = byId(resp.serverVmId);
    this.clientVm = (mode === "test" || mode === "play") ? byId(resp.clientVmId) : null;
  }

  async getMode(): Promise<string> {
    return await this.daemon.request<string>("studio.getMode", { studioHandle: this.studioHandle });
  }

  async save(): Promise<{ saved: boolean; path?: string; error?: string }> {
    return await this.daemon.request<{ saved: boolean; path?: string; error?: string }>(
      "studio.save", { studioHandle: this.studioHandle },
    );
  }

  async close(): Promise<void> {
    await this.daemon.request<null>("studio.close", { studioHandle: this.studioHandle });
  }

  async getVms(): Promise<Vm[]> {
    // Studio-first snapshot: this Studio's VMs live under its entry in
    // state.studios[].vms (keyed by sessionGuid == studio.id).
    const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
    const studio = (state.studios ?? []).find((s) => s.id === this.sessionGuid);
    if (!studio) return [];
    return (studio.vms ?? []).map((sv) => new Vm(buildVmSnapshot(studio, sv), this.daemon));
  }

  /** Start an isolated multiplayer test (one server + `numPlayers` clients).
   *  Requires this Studio to be open (the headless backend-level entrypoint is
   *  gone). Returns a MultiplayerTest holding Vm handles for the server and
   *  each client; run code via the normal `vm.runCode` path on those handles. */
  async startMultiplayerTest(numPlayers: number): Promise<MultiplayerTest> {
    const resp = await this.daemon.request<{
      mpHandle: string;
      serverVmId: string;
      clientVmIds: string[];
    }>("studio.startMultiplayerTest", { studioHandle: this.studioHandle, numPlayers });

    const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
    const server = vmById(state, resp.serverVmId, this.daemon, "server");
    const clients = resp.clientVmIds.map((id) => vmById(state, id, this.daemon, "client"));
    return new MultiplayerTest(resp.mpHandle, server, clients, this.daemon);
  }
}

// ---------------------------------------------------------------------------
// MultiplayerTest — handle to an isolated multiplayer test. `server` and
// `clients` are ordinary Vm handles (run code via `runCode`); the lifecycle
// methods are keyed by the daemon-side `mpHandle`.
// ---------------------------------------------------------------------------

export class MultiplayerTest {
  server: Vm;
  clients: Vm[];
  private mpHandle: string;
  private daemon: Daemon;

  constructor(mpHandle: string, server: Vm, clients: Vm[], daemon: Daemon) {
    this.mpHandle = mpHandle;
    this.server = server;
    this.clients = clients;
    this.daemon = daemon;
  }

  /** Add `n` more client players; rebuilds `clients` from the latest state. */
  async addPlayers(n: number): Promise<void> {
    const resp = await this.daemon.request<{ clientVmIds: string[] }>(
      "mp.addPlayers", { mpHandle: this.mpHandle, numPlayers: n },
    );
    const state = await this.daemon.request<StateSnapshotDTO>("client.getState");
    this.clients = resp.clientVmIds.map((id) => vmById(state, id, this.daemon, "client"));
  }

  /** Disconnect the client player at `index`. */
  async leave(index: number): Promise<void> {
    await this.daemon.request<null>("mp.leave", { mpHandle: this.mpHandle, index });
  }

  /** End the multiplayer test (tears down server + all clients). */
  async end(): Promise<void> {
    await this.daemon.request<null>("mp.end", { mpHandle: this.mpHandle });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Build a full VmSnapshotDTO from a studio-first snapshot's parent studio +
// its minimal vm entry. The studio entries carry only vmId/dom/clientName, so
// the remaining fields are sourced from the owning studio.
function buildVmSnapshot(studio: StudioDTO, sv: StudioVmEntryDTO): VmSnapshotDTO {
  return {
    vmId: sv.vmId,
    dom: sv.dom,
    mode: sv.dom === "edit" ? "edit" : studio.mode,
    backendId: studio.backendId,
    sessionGuid: studio.id,
    placeId: studio.placeId,
    gameName: studio.name,
    connected: true,
    activeRuns: 0,
    clientName: sv.clientName ?? undefined,
  };
}

// Build every Vm across all studios in a studio-first snapshot.
function vmsFromStudios(state: StateSnapshotDTO, daemon: Daemon): Vm[] {
  const out: Vm[] = [];
  for (const studio of state.studios ?? []) {
    for (const sv of studio.vms ?? []) {
      out.push(new Vm(buildVmSnapshot(studio, sv), daemon));
    }
  }
  return out;
}

// Find a vmId across state.studios[].vms and return the built VmSnapshotDTO,
// or undefined if no studio owns it.
function findVmSnapshot(state: StateSnapshotDTO, vmId: string): VmSnapshotDTO | undefined {
  for (const studio of state.studios ?? []) {
    for (const sv of studio.vms ?? []) {
      if (sv.vmId === vmId) return buildVmSnapshot(studio, sv);
    }
  }
  return undefined;
}

// Resolve a vmId in a studio-first snapshot to a Vm, throwing a labeled error
// if no studio owns it. `label` ("server"/"client") sharpens the message.
function vmById(state: StateSnapshotDTO, vmId: string, daemon: Daemon, label: string): Vm {
  const snap = findVmSnapshot(state, vmId);
  if (!snap) throw new Error(`${label} VM ${vmId} not found`);
  return new Vm(snap, daemon);
}

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
