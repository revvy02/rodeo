/** Extract the GUID printed as `MARKER:<guid>` from a captured output string.
 *  Shared between profile and log test helpers — both use a script-side
 *  `HttpService:GenerateGUID(false)` + `print("MARKER:" .. guid)` to mint a
 *  unique correlation token the test runner can re-discover in collected output. */
export function extractMarker(output: string): string {
  const m = output.match(/MARKER:([0-9A-F-]{32,})/i);
  if (!m) throw new Error(`expected MARKER:<guid> in output; got:\n${output.slice(0, 1000)}`);
  return m[1];
}
