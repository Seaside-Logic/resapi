# Release process

How a resAPI version gets from a commit to npm. Every step that makes something public is done by a maintainer, never by CI on its own or by an AI agent without explicit approval.

## Versions

- All four packages share one version. The first release is `0.1.0`.
- 0.x releases follow semver as far as they can, with the caveat that a 0.x minor release can break the API. Record breaking changes in [CHANGELOG.md](../CHANGELOG.md) with migration notes.
- Adapters depend on `@resapi/core` with `^<version>`, so they accept core patch releases.
- New versions go to the `next` dist-tag first and are promoted to `latest` after a smoke test.

## One-time setup

1. **npm account:** enable two-factor authentication. On the `@resapi` organization, require 2FA for members and review who has publish rights.
2. **GitHub:** create an environment named `npm` and add yourself as a required reviewer. Every run of `release.yml` then waits for your approval.
3. **First publish (bootstrap).** Trusted publishers are configured per package, and the packages don't exist on npm until their first publish. Publish 0.1.0 once from your own authenticated machine (steps 1–7 below, then `npm publish --workspace=@resapi/<pkg> --access public --tag next` in the order core, sury, hono, express). npm's newer `npm stage publish` can also create a package. Check the current [trusted publishing docs](https://docs.npmjs.com/trusted-publishers/) before you start.
4. **Trusted publishers.** On npmjs.com, configure each package with organization `Seaside-Logic`, repository `resapi`, workflow `release.yml` and environment `npm`. `repository.url` in each package.json must match the repository exactly. npm doesn't validate the configuration when you save it, and a configuration that hasn't published successfully within about two days expires. Configure it shortly before the next release.

No npm token is stored in GitHub at any point.

## Releasing a version

1. Make sure `main` is green in CI and the [CHANGELOG](../CHANGELOG.md) entry is written.
2. Set the version in all four `packages/*/package.json`, plus the `@resapi/core` range in the three adapters.
3. **First release only:** remove `"private": true` from the four package.json files. It is there so nothing can be published by accident before 0.1.0.
4. Re-read `@rescript/webapi`'s Fetch modules (`src/fetch/*.res`, `src/event/Abort*.res` on its `main`) and update `packages/core/src/Fetch.res` if anything resAPI mirrors was renamed. Update the mirrored-commit note at the top of the file.
5. Run `npm install` to update the lockfile, then `npm run release:check`. It runs formatting, tests, the isolation check, the Workers tests and the tarball and doc install checks.
6. Inspect the tarballs yourself: `npm pack --workspace=@resapi/<pkg> --dry-run`.
7. Commit as `release: v<version>`.
8. Tag and push: `git tag v<version> && git push origin main v<version>`.
9. Approve the `npm` environment when `release.yml` asks. It reruns `release:check`, checks that the tag matches every package version, and publishes core, sury, hono and express to `next` with provenance.
10. Check each package on npmjs.com: version, README, license, dependencies, and the provenance badge.
11. Smoke test from the registry in a fresh project: `npm install @resapi/core@next @resapi/sury@next @resapi/hono@next` (and Express), then build and run a contract, an endpoint and a client call.
12. Promote all four together: `npm dist-tag add @resapi/<pkg>@<version> latest`. The first publish of a new package sets `latest` automatically, whatever `--tag` says, so 0.1.0 needed no promotion.
13. Create the GitHub release for the tag from the CHANGELOG entry.

The workflow skips any package whose version is already on npm. If a publish fails partway, fix the cause and rerun the workflow for the same tag. Don't retag. The same rule makes the v0.1.0 tag safe to push after the manual bootstrap publish: the run checks everything and publishes nothing.

## Documentation layout

The go-live plan listed eight guides. They are folded into fewer files, so nothing exists twice:

| Planned | Where it lives |
| --- | --- |
| getting-started, hono, cloudflare | [getting-started.md](getting-started.md), which uses Hono on Workers |
| express | [express.md](express.md) |
| contracts, client | [api.md](api.md) plus getting-started sections 2 and 5 |
| errors | [errors.md](errors.md) |
| architecture | [architecture.md](architecture.md) |

Whole-file examples in the README, getting-started and the Express guide are compiled and run against the packed packages by `npm run check:packages`. To have a block checked, give it a first line of `// Name.res`.
