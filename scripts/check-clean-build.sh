#!/usr/bin/env bash
# Builds and tests a fresh clone of HEAD (no stale artifacts), then checks that incremental builds notice
# changes that must break dependents: a contract type, a core API used by another package, and a
# package dependency in rescript.json. Each edit must fail the incremental build; reverting must fix it.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT

git clone -q "$REPO" "$DIR/resapi"
cd "$DIR/resapi"
npm ci --no-audit --no-fund >/dev/null
npm run build >/dev/null
npm test >/dev/null
npm run check:isolation >/dev/null
npm run format:check >/dev/null
echo "ok - fresh clone installs, builds, tests and passes the isolation and format checks"

# must_break <description> <file> <sed expression>: the edit must fail an incremental build, the revert
# must pass one.
must_break() {
  local description=$1 file=$2 expression=$3
  sed -i.bak "$expression" "$file"
  if npx rescript >"$DIR/build.log" 2>&1; then
    echo "FAIL - incremental build succeeded after: $description"
    exit 1
  fi
  mv "$file.bak" "$file"
  npx rescript >"$DIR/build.log" 2>&1 || { cat "$DIR/build.log"; echo "FAIL - build broken after reverting: $description"; exit 1; }
  echo "ok - incremental build catches: $description"
}

must_break "a field removed from a shared contract type" \
  examples/cloudflare/src/Api/AccountApi.res 's/^  balance: float,$/  balanceX: float,/'
must_break "a core function renamed (used by other packages)" \
  packages/core/src/Client.res 's/^let callWithBody = send$/let callWithBodyX = send/'
must_break "a package dependency removed from rescript.json" \
  examples/cloudflare/rescript.json 's/"@resapi\/sury", //'
