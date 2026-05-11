import { spawn, type Subprocess } from "bun";

// NDJSON JSON-RPC 2.0 wire types — match `rodeo-cli/src/commands/spawn_canonical_client.rs`.
type WireRequest = { jsonrpc: "2.0"; id: number; method: string; params: unknown };
type WireResponse = {
  jsonrpc: "2.0";
  id: number;
  result?: unknown;
  error?: { code: number; message: string; data?: unknown };
};
type WireNotification = { jsonrpc: "2.0"; method: string; params: { streamId?: string; [k: string]: unknown } };

type PendingRequest = {
  resolve: (value: unknown) => void;
  reject: (err: Error) => void;
};

/** Callback receives (notificationMethod, params) for every `stream.*` message
 * tagged with the registered `streamId`. */
type StreamCallback = (method: string, params: Record<string, unknown>) => void;

/**
 * Spawns `rodeo __spawn_canonical_client` and brokers JSON-RPC over NDJSON on
 * its stdin/stdout. One daemon per RodeoClient instance — cheap to spawn,
 * dies on stdin close.
 */
export class Daemon {
  private proc: Subprocess<"pipe", "pipe", "inherit"> | undefined;
  private nextId = 1;
  private pending = new Map<number, PendingRequest>();
  private streams = new Map<string, StreamCallback>();
  private stdoutBuf = "";
  private writeEncoder = new TextEncoder();

  constructor(private host: string, private port: number) {
    this.start();
  }

  private start() {
    this.proc = spawn({
      cmd: ["rodeo", "__spawn_canonical_client", "--host", this.host, "--port", String(this.port)],
      stdin: "pipe",
      stdout: "pipe",
      stderr: "inherit",
    });
    // Fire-and-forget reader — runs until stdout closes.
    this.readLoop().catch(() => {});
    // Fire-and-forget exit watcher — fails pending requests.
    this.proc.exited.then(() => this.drainPending(new Error("daemon subprocess exited")));
  }

  private async readLoop() {
    if (!this.proc?.stdout) return;
    const reader = this.proc.stdout.getReader();
    const decoder = new TextDecoder();
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      this.stdoutBuf += decoder.decode(value, { stream: true });
      let idx: number;
      while ((idx = this.stdoutBuf.indexOf("\n")) >= 0) {
        const line = this.stdoutBuf.slice(0, idx);
        this.stdoutBuf = this.stdoutBuf.slice(idx + 1);
        if (line.trim()) this.handleLine(line);
      }
    }
    this.drainPending(new Error("daemon stdout closed"));
  }

  private handleLine(line: string) {
    let msg: WireResponse | WireNotification;
    try { msg = JSON.parse(line); } catch { return; }

    if ("id" in msg && typeof msg.id === "number") {
      // Response
      const pending = this.pending.get(msg.id);
      if (!pending) return;
      this.pending.delete(msg.id);
      if (msg.error) {
        pending.reject(new Error(msg.error.message));
      } else {
        pending.resolve(msg.result);
      }
      return;
    }
    if ("method" in msg) {
      // Notification — route by streamId
      const streamId = (msg.params as { streamId?: string } | undefined)?.streamId;
      if (typeof streamId === "string") {
        const cb = this.streams.get(streamId);
        cb?.(msg.method, msg.params as Record<string, unknown>);
      }
    }
  }

  private drainPending(err: Error) {
    for (const [, p] of this.pending) p.reject(err);
    this.pending.clear();
  }

  /** Send a JSON-RPC request and resolve with its `result`. */
  request<T>(method: string, params: unknown = {}): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      if (!this.proc?.stdin) {
        reject(new Error("daemon stdin not available"));
        return;
      }
      const id = this.nextId++;
      this.pending.set(id, { resolve: resolve as (v: unknown) => void, reject });
      const req: WireRequest = { jsonrpc: "2.0", id, method, params };
      const line = JSON.stringify(req) + "\n";
      // Bun's pipe stdin is a FileSink — write is synchronous.
      this.proc.stdin.write(this.writeEncoder.encode(line));
      // Force flush so the daemon sees the line immediately.
      (this.proc.stdin as unknown as { flush?: () => void }).flush?.();
    });
  }

  /** Register a callback for stream notifications keyed by `streamId`.
   * Unregister when `stream.done` / `stream.error` arrives. */
  registerStream(streamId: string, cb: StreamCallback) {
    this.streams.set(streamId, cb);
  }

  unregisterStream(streamId: string) {
    this.streams.delete(streamId);
  }

  /** Close stdin → daemon exits → all open Studios are detached (not closed).
   * Matches `Studio.close()`-is-explicit semantics. */
  async shutdown() {
    try { this.proc?.stdin?.end(); } catch {}
    try { await this.proc?.exited; } catch {}
  }
}
