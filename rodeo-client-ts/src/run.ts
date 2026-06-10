//! Types only — runCode implementation now lives in `client.ts` as a thin
//! wrapper over the canonical-client daemon. These types are kept in this
//! file so consumers importing `./run.js` see no breakage.

export type LogFilter = {
  enableWarn?: boolean;
  enableError?: boolean;
  enableInfo?: boolean;
  enableOutput?: boolean;
  enableLogs?: boolean;
};

export type RunCodeOpts = {
  source?: string;
  file?: string;
  sourcemap?: string;
  target?: string;
  showReturn?: boolean;
  cacheRequires?: boolean;
  verbose?: boolean;
  scriptArgs?: string[];
  profile?: string;
  /** Write the script's return value to this host-side path. `.luau`/`.lua`
   *  emits Luau source (e.g. `return { pos = Vector3.new(1,2,3) }`); any
   *  other extension emits JSON-encoded tagged structs. */
  returnFile?: string;
  processName?: string;
  logFilter?: LogFilter;
};

export type RunResult = {
  ok: boolean;
  output: string;
  exitCode: number;
  /** JSON-parsed script return value. `undefined` if the script returned
   *  nothing, if a returnFile captured the value instead, or if the return
   *  payload failed to parse (the latter is swallowed defensively — never
   *  throws at the consumer). */
  return?: unknown;
};
