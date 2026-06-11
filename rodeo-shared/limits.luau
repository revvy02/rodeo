-- Transport size limits shared by the plugin runner and (eventually) the
-- live-vluau runtime host.
--
-- The done message carrying `ExecutionDone.return_value` is a single
-- unchunkable message on every hop, and the binding transport constraint is
-- connectrpc's 4,194,304-byte per-envelope cap (backend→master and
-- master→client). 2MiB of raw JSON leaves 2x margin there and ~4x on the
-- plugin WS hop after worst-case JSON-in-JSON escaping. Values larger than
-- this must go through a --return file (chunked, size-unbounded) instead.
return {
	MAX_WIRE_RETURN_BYTES = 2 * 1024 * 1024,
}
