# CLAUDE.md

resAPI: contract-first HTTP toolkit for ReScript. Packages: `@resapi/core` (contracts, codecs, client; no Hono/Sury/Cloudflare imports), `@resapi/hono` (server adapter), `@resapi/sury` (Sury codec adapter). Neither adapter depends on the other.

## Commands

```bash
npm install
npm run build        # compile all ReScript (root rescript.json builds every workspace package)
npm run watch
npm test             # build + node --test
npx rescript clean   # clear stale build state
```

## ReScript gotchas

- Module names are global across the workspace unless a package is namespaced. Keep names unique.
- Rewatch ignores `sources.public`. Hide modules with a `.resi` file.
- After editing any `rescript.json`, run `npx rescript clean`. Incremental builds can report false success.
- Top-level values with free type variables fail with "cannot be generalized". Annotate, e.g. `Router.t<unit>`.
- ReScript exceptions are not JS `Error`s (`instanceof Error` is false).
- ReScript 12 has a built-in stdlib. Don't add `@rescript/core`.
- Sury codecs must be built at module top level: Workers forbid `new Function` during a request. Node tests won't catch this; test under workerd.

## Conventions

- Pin dependency versions exactly. Don't publish, push, or deploy.
- No unsafe casts (`Obj.magic`, `%identity`) to reach a syntax target. Compile-time safety claims need a compile-fail case.
- Compiled `*.res.mjs` is gitignored.
