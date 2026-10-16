# Contributing

Bug reports, documentation fixes and pull requests are welcome. For anything larger than a fix, open an issue first, so we can agree on the approach before you write code.

Report security problems privately, as described in [SECURITY.md](SECURITY.md).

## Setup

Requires Node 22 or later.

```bash
npm install
npm run build
npm test
```

## Checks

Run `npm run release:check` before opening a pull request. It runs:

- `npm run format:check`: ReScript formatting (`npm run format` fixes it)
- `npm test`: unit, integration and compile-fail tests
- `npm run check:isolation`: package boundaries in the compiled import graph
- `npm run test:worker`: the Workers example and probes under `wrangler dev`
- `npm run check:packages`: packs the packages and installs them in fresh projects, including the doc examples

## Conventions

- Each package's public API is its `.resi` files. Keep implementation helpers out of them.
- Every new compile-time guarantee gets a case in `tests/compile-fail/cases/`, with the expected error in its `// expect:` line.
- No unsafe casts (`Obj.magic`, `%identity`). The only exception is `ResApi.Fetch`, which mirrors `@rescript/webapi` exactly, including its `%identity` constructors for union-typed init values. Changes to `Fetch.res` must match webapi's names, labels, types and record fields.
- Core must not import Hono, Express, Sury or any runtime-specific module, and no adapter depends on another.
- After editing any `rescript.json`, run `npx rescript clean`.
- Whole-file doc examples start with `// Name.res` and are compiled by `check:packages`. Keep them working.
- User-visible changes get a line in [CHANGELOG.md](CHANGELOG.md).

[site/content/architecture.md](site/content/architecture.md) explains the design and the reasons behind it.
