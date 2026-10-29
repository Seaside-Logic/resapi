# Release process

How a resAPI version gets from a commit to npm. Every step that makes something public is done by a maintainer, never by CI on its own or by an AI agent without explicit approval.

## Versions

- All four packages share one version. The first release is `0.1.0`.
- 0.x releases follow semver as far as they can, with the caveat that a 0.x minor release can break the API. Record breaking changes in [CHANGELOG.md](../CHANGELOG.md) with migration notes.
- Adapters depend on `@resapi/core` with `^<version>`, so they accept core patch releases.
- New versions go to the `next` dist-tag first and are promoted to `latest` after a smoke test.

## Releasing a version

1. Make sure `main` is green in CI and the [CHANGELOG](../CHANGELOG.md) entry is written.
2. Set the version in all four `packages/*/package.json`, plus the `@resapi/core` range in the three adapters.
3. Re-read `@rescript/webapi`'s Fetch modules (`src/fetch/*.res`, `src/event/Abort*.res` on its `main`) and update `packages/core/src/Fetch.res` if anything resAPI mirrors was renamed. Update the mirrored-commit note at the top of the file.
4. From the repo root, run `npm install --package-lock-only` to update the lockfile (plain `npm install` skips the workspace versions when `node_modules` is already up to date), then `npm run release:check`. It runs formatting, tests, the isolation check, the Workers tests and the tarball and doc install checks.
5. Inspect the tarballs yourself: `npm pack --workspace=@resapi/<pkg> --dry-run`.
6. Commit as `release: v<version>`.
7. Tag and push: `git tag v<version> && git push origin main v<version>`.
8. Approve the `npm` environment when `release.yml` asks. It reruns `release:check`, checks that the tag matches every package version, and publishes core, sury, hono and express to `next` with provenance.
9. Check each package on npmjs.com: version, README, license, dependencies, and the provenance badge.
10. Smoke test from the registry in a fresh project: `npm install @resapi/core@next @resapi/sury@next @resapi/hono@next` (and Express), then build and run a contract, an endpoint and a client call.
11. Promote all four together: `npm dist-tag add @resapi/<pkg>@<version> latest`. The first publish of a new package sets `latest` automatically, whatever `--tag` says, so 0.1.0 needed no promotion.
12. Create the GitHub release for the tag from the CHANGELOG entry.

The workflow skips any package whose version is already on npm. If a publish fails partway, fix the cause and rerun the workflow for the same tag. Don't retag. The same rule makes the v0.1.0 tag safe to push after the manual bootstrap publish: the run checks everything and publishes nothing.
