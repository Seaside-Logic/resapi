#!/usr/bin/env bash
# Packs the four packages and checks the tarballs themselves: exactly the intended files, the root
# LICENSE, and no workspace-only dependency versions. Then installs them from the tarballs into fresh
# projects outside the repo, one per tests/consumer scenario, and builds and runs each one. The doc
# scenarios build the whole-file examples from README.md and site/content/ (see extract-doc-files.mjs), once per
# framework for a doc with Hono and Express versions.
#
# RESAPI_FROM=<dist-tag> (e.g. next) skips packing and installs the published packages from the npm
# registry instead: the smoke test after a release.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT
cd "$REPO"

fail() { echo "FAIL - $*"; exit 1; }

FROM=${RESAPI_FROM:-}
for pkg in core hono express sury; do
  [ -z "$FROM" ] || break
  npm pack --silent --workspace="@resapi/$pkg" --pack-destination "$DIR" >/dev/null
  tarball=$(ls "$DIR"/resapi-$pkg-*.tgz)

  expected=$( (printf '%s\n' LICENSE README.md package.json rescript.json
    git ls-files "packages/$pkg/src/*.res" "packages/$pkg/src/*.resi" | sed "s|^packages/$pkg/||") | sort)
  actual=$(tar -tzf "$tarball" | sed 's|^package/||' | sort)
  [ "$expected" = "$actual" ] || fail "@resapi/$pkg contents differ:
$(diff <(echo "$expected") <(echo "$actual") || true)"

  tar -xzOf "$tarball" package/LICENSE | cmp -s - LICENSE || fail "@resapi/$pkg LICENSE differs from the root LICENSE"
  manifest=$(tar -xzOf "$tarball" package/package.json)
  if grep -Eq '": "(\*|workspace:|file:|link:)' <<<"$manifest"; then fail "@resapi/$pkg has a workspace-only dependency version"; fi
  if grep -Fq "$REPO" <<<"$manifest"; then fail "@resapi/$pkg package.json contains a local path"; fi
  echo "ok - @resapi/$pkg tarball: $(wc -l <<<"$actual" | tr -d ' ') files"
done

# tgz <pkg>: what to install for a package, the packed tarball or the published dist-tag.
tgz() { if [ -n "$FROM" ]; then echo "@resapi/$1@$FROM"; else ls "$DIR"/resapi-"$1"-*.tgz; fi; }
RESCRIPT=$(node -p 'require("./package.json").devDependencies.rescript')
SURY=(sury@11.0.0 sury-ppx@11.0.0)

# scenario <dir> <packages to install...>: a fresh npm project in $DIR, outside the repo and its workspace.
scenario() {
  local name=$1; shift
  local project="$DIR/consumer-$name"
  mkdir -p "$project/src"
  cp "tests/consumer/$name/rescript.json" "$project/"
  cp tests/consumer/shared/*.res "tests/consumer/$name/"*.res "$project/src/"
  # A doc scenario gets its doc's files instead of the shared contract.
  if [ -n "${DOC:-}" ]; then
    node scripts/extract-doc-files.mjs "$DOC" "$project" ${FRAMEWORK:-} >/dev/null
  elif grep -q '"sury"' "tests/consumer/$name/rescript.json"; then
    cp tests/consumer/shared-sury/*.res "$project/src/"
  fi
  (
    cd "$project"
    npm init -y >/dev/null
    npm install --no-audit --no-fund "rescript@$RESCRIPT" "$@" >"$project/install.log" 2>&1 ||
      { cat "$project/install.log"; fail "$name: npm install"; }
    npx rescript >"$project/build.log" 2>&1 || { cat "$project/build.log"; fail "$name: build"; }
    node src/Main.res.mjs || fail "$name: run"
  )
}

scenario handwritten "$(tgz core)"
scenario sury-client "$(tgz core)" "$(tgz sury)" "${SURY[@]}"
scenario hono "$(tgz core)" "$(tgz sury)" "$(tgz hono)" "${SURY[@]}" hono@4.13.13
scenario express "$(tgz core)" "$(tgz sury)" "$(tgz express)" "${SURY[@]}" express@5.2.1

DOC=README.md scenario doc-readme "$(tgz core)" "$(tgz sury)" "$(tgz hono)" "$(tgz express)" "${SURY[@]}" hono@4.13.13 express@5.2.1
DOC=site/content/getting-started.md FRAMEWORK=hono scenario doc-getting-started-hono "$(tgz core)" "$(tgz sury)" "$(tgz hono)" "${SURY[@]}" hono@4.13.13
DOC=site/content/getting-started.md FRAMEWORK=express scenario doc-getting-started-express "$(tgz core)" "$(tgz sury)" "$(tgz express)" "${SURY[@]}" express@5.2.1
DOC=site/content/middleware.md FRAMEWORK=hono scenario doc-middleware-hono "$(tgz core)" "$(tgz sury)" "$(tgz hono)" "${SURY[@]}" hono@4.13.13
DOC=site/content/middleware.md FRAMEWORK=express scenario doc-middleware-express "$(tgz core)" "$(tgz sury)" "$(tgz express)" "${SURY[@]}" express@5.2.1
