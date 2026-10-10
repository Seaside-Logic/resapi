#!/usr/bin/env bash
# Checks under `wrangler dev` (workerd), which enforces Workers restrictions Node doesn't:
#   1. the example's tests pass over HTTP (codecs built at module load, typed env binding);
#   2. a probe Worker that builds a Sury codec during a request fails, proving the check can fail;
#   3. a Worker with a mismatched route fails to start.
# Workers run one at a time: concurrent `wrangler dev` instances contend for shared local ports.
set -euo pipefail
cd "$(dirname "$0")/.."
export WRANGLER_SEND_METRICS=false
PORT=${PORT:-8797}
LOG=$(mktemp)
PID=

stop() {
  if [ -n "$PID" ]; then kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; fi
  PID=
}
trap 'stop; rm -f "$LOG"' EXIT

# start <dir> <wrangler args...>: runs `wrangler dev` in the background, logging to $LOG, on the next
# free pair of ports from $PORT (HTTP, then inspector) in $URL. Each run gets its own ports: on Linux a
# stopped Worker's workerd can still hold its ports when the next one starts.
RUN=0
start() {
  local dir=$1
  shift
  local http=$((PORT + RUN * 2))
  RUN=$((RUN + 1))
  URL="http://localhost:$http"
  : >"$LOG"
  (cd "$dir" && exec npx wrangler dev --port "$http" --inspector-port "$((http + 1))" "$@" >"$LOG" 2>&1) &
  PID=$!
}

# wait_for <pattern>: waits up to 30s for the pattern in the log.
wait_for() {
  for _ in $(seq 1 60); do grep -q "$1" "$LOG" && return 0; sleep 0.5; done
  cat "$LOG"
  return 1
}

npx rescript

start examples/cloudflare --var API_SECRET:test-secret
wait_for "Ready on"
RESAPI_BASE_URL="$URL" node --test tests/example.test.mjs
stop

start tests/fixtures -c wrangler.probe.jsonc
wait_for "Ready on"
status=$(curl -s -o /dev/null -w '%{http_code}' "$URL/lazy-codec")
[ "$status" = 500 ] || { echo "probe: expected 500 for a codec built during a request, got $status"; exit 1; }
wait_for "Code generation from strings disallowed"
echo "ok - workerd rejects a Sury codec built during a request"
stop

start tests/fixtures -c wrangler.bad.jsonc
wait_for 'Uncaught Error: Invalid route "/accounts/:accountId"'
echo "ok - a Worker with a mismatched route fails to start"
