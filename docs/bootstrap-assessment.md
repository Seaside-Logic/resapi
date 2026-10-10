# Bootstrap assessment

This report evaluates resAPI at the end of its initial implementation. It answers the evaluation questions and the final decision points of the bootstrap guide.

**Short version.** The contract architecture survived the move intact. Package boundaries hold on the compiled output. Typed errors fit without disturbing inference. The example runs under workerd, with checks proving that workerd enforces what Node doesn't. resAPI isn't ready for a public preview yet. The blockers are mostly packaging: it has never been installed outside this workspace.

## Evidence base

Every claim below is backed by one of these:

| Check | Command | Result at `HEAD` |
| --- | --- | --- |
| Runtime tests (client, server, middleware, route checking, typed errors, Sury, example in-process) | `npm test` | 75 pass |
| Compile-fail cases (each must fail with an expected message; `ok.res` must compile) | `npm test` | 24 pass |
| Example over HTTP under `wrangler dev`, plus 2 negative workerd checks | `npm run test:worker` | 7 tests + 2 checks pass |
| Package boundaries in the compiled import graph | `npm run check:isolation` | 11 pass, including a positive control |
| Fresh clone builds and tests, and incremental builds catch breaking edits | `npm run check:clean-build` | 4 pass |
| Deploy bundle | `wrangler deploy --dry-run` | 188.7 KiB, 46.7 KiB gzip, no `node:` imports |

The key checks were mutation-tested, meaning each was made to fail by breaking the property it guards. These are the compile-fail harness, request-validation ordering, the exception guard and the isolation check. The workerd probe is itself a negative check. The bad-route Worker check and the clean-build check were not mutation-tested.

**Not verified:**
- **CI.** The workflow has never run, because nothing is pushed.
- **Real deploys.** None were authorized.
- **Installing the packages outside this workspace.**

## 1. Architecture

**Did the package structure produce genuine separation? Yes.**
- **Core:** reaches no Hono, Sury, `node:` or `cloudflare:` module.
- **Sury adapter:** reaches no Hono.
- **Hono adapter:** reaches no Sury.
- **Example client:** reaches neither Hono nor Cloudflare.

`scripts/check-isolation.mjs` checks this on the compiled import graph. The check matters because ReScript emits an `@module` external's import where the external is *called*, not where it is declared. `import {Hono} from "hono"` appears in the app module that calls `Router.make`, never in `Router.res.mjs`. Grepping a package's own output would therefore prove nothing.

**Unwanted dependencies or cycles: none.** The dependency direction is core ← hono and core ← sury. `RouteCheck` takes `(path, codec)` instead of a contract, which avoids a core-internal cycle with `Endpoint`.

**Changes from the planned layout:**
- **No `@resapi/cloudflare` package.** A Hono app is already a valid Worker module, so `let default = App.app` works under workerd.
- **No `Middleware.res`.** Hono's built-ins replace the POC's logger and header middleware.
- **Fetch bindings moved into core** as `Fetch.Request` and `Fetch.Response`, because the client and the server both need them.

Library size, counting non-blank, non-comment lines:

| | POC | resAPI |
| --- | --- | --- |
| Core: contracts, codecs, client, Fetch | 117 (95 + 22 for the contract half of Endpoint) | 182 |
| Route checking | 32 (prototype) | 70 |
| Server: router, context, handler, middleware | 131 (79 + 52 for the server half of Endpoint) | 150 |
| Sury adapter | 17 | 17 |
| Cloudflare adapter | 6 | 0 |
| **Total** | 303 | 419 |

The growth comes from three places:
- **Typed errors:** the contract fields, `withErrors`, server encoding and client decoding.
- **Route checking:** explicit outcomes, unsupported-syntax and duplicate detection.
- **Client fixes:** URL joining, error classification, narrowed `try`.

## 2. API ergonomics

**Does resAPI remain concise and idiomatic? Yes.** Plain contracts are written exactly as in the POC. Handlers keep the same shape. Inference needs no new annotations.

| | POC | resAPI |
| --- | --- | --- |
| Opens | `open Rono` | `open ResApi` and, in server code, `open ResApiHono` |
| Contract | `Endpoint.get(path, ~params, ~response)` | Same |
| Declared errors | Not available | `->Endpoint.withErrors(codec, ~status=e => ...)` |
| Server route | `contract->Endpoint.handle(async (ctx, {params}) => ...)` | `contract->EndpointHandler.make(async (ctx, {params}) => ...)` |
| Not found | `Error(Endpoint.notFound("No account"))` | `Error(NotFound)`, which must be declared |
| Worker entry | `let default = Cloudflare.worker(App.app)` | `let default = App.app` |
| Client not-found | `Error(UnexpectedStatus({status: 404}))` | `Error(Application({error: NotFound}))` |
| Middleware | `next => async ctx => ...` (resAPI-specific) | `async (ctx, next) => {...; None}` (Hono's shape) |

**Boilerplate added:**
- **Typed errors cost about 9 lines per endpoint** that uses them, with sury-ppx: an `@schema` variant, `SuryCodec.make`, and a `switch` for the status.
- **Endpoints without errors cost nothing.**
- **Explicit annotations need a fourth parameter:** `Endpoint.t<_, _, _>` becomes `Endpoint.t<_, _, _, _>`. In the codebase, this touched 3 test cases and 2 library lines.
- **The second `open`** comes from the package split.
- **The value restriction is unchanged.** A top-level router or route that never reads `Context.env` still needs `Router.t<unit>` or `EndpointHandler.route<unit>`. It caught two snippets in the draft documentation, which is a sign users will meet it too.

## 3. Type safety

**Enforced by the compiler.** Each item is backed by a compile-fail case:

- **Client calls:**
  - wrong param field
  - wrong param type
  - missing param field
  - missing body (`call` on a POST contract)
  - wrong body type
  - wrong response field
  - wrong application-error constructor
- **Handlers:**
  - wrong response type
  - wrong param type
  - nonexistent param or body field
  - returning an undeclared error type
  - returning any error from an endpoint that declares none
- **Contracts:**
  - incompatible codec for the declared type
  - a GET with a body
  - a POST without a body
  - Sury schema type flowing into the contract
  - `withErrors` applied twice
- **Environment:**
  - misspelled binding
  - middleware for a different environment type
- **Registration:** registering a contract that has no handler.

**Enforced at runtime:**
- route params against the params codec, at module load
- request params, then body JSON, then body
- response and application-error bodies on the client
- application-error status range on the server

**Not checked at all:** the environment bindings type, which is a declaration, like any external. Codec correctness is also trusted: an encoder can produce JSON its own decoder rejects.

**Unsafe casts: none.** There is no `Obj.magic`, `%identity` or `%raw`. The only trust boundaries are ordinary externals.

**Regressions from the POC:**
- **Hono is no longer hidden from applications.** The POC used `.resi` files to make Hono unreachable. The guide allows exposing Hono, and doing so is what makes Hono's built-in middleware usable. This is a deliberate change of goal, not a type-safety loss.
- **Middleware can no longer catch a handler's exception.** Hono turns it into a 500 response at the handler layer, which is Hono's native behavior. The POC overrode this.
- **The `requireUser` typed-user example and its compile-fail case were dropped** with the demo's `/me` route. The pattern still works, because it is plain function composition, but it is no longer demonstrated.

**Finding about the POC's evidence.** The compile-fail harness inherited from the POC could pass without checking anything. The compiler's error excerpt prints neighboring source lines. When the error was near the top of the file, those lines included the case's own `// expect:` comment, so every expectation matched itself. A deliberately wrong expectation still passed. resAPI's harness blanks that line before compiling, and the same mutation now fails. Some of the POC's cases may have been vacuous. This wasn't re-checked in the POC repository, which this work does not modify.

## 4. Interoperability

**Hono-specific code:** 150 lines in `@resapi/hono`. That covers router bindings and wrappers (47), context bindings (23) and typed-endpoint execution (80).

**Can ordinary Hono capabilities be reached? Yes.**
- **`Router.t` is the Hono app.** Any unwrapped Hono API binds against it with one external.
- **Built-in middleware works unchanged:**
  - `hono/logger` is used in the example and tests.
  - `hono/bearer-auth` is used in the example with the typed env binding, built per request (Hono's documented pattern). Its `HTTPException` responses pass through the adapter untouched.

**Reliance on undocumented Hono behavior:**
- **The POC's two overrides are gone:**
  - **Header-merging `c.res` replacement:** the POC replaced responses instead of letting Hono merge their headers.
  - **Rethrowing `onError`:** the POC rethrew every error so that middleware could catch it.
- **One adaptation remains.** Hono's `compose` and `#handleError` only handle `instanceof Error` and rethrow anything else out of `app.fetch`. This was read from Hono 4.13.13's source, and raw ReScript exceptions are plain objects. `Router.get`, `post` and `use` therefore rethrow non-`Error` exceptions as JS `Error`s and leave the rest to Hono's default `onError`. If Hono stopped turning those rethrown `Error`s into a 500, the no-middleware exception test would fail. That test is mutation-checked: removing the guard fails it today.

## 5. Client behavior

**Are errors classified correctly? Yes.** Only `fetch` itself sits inside a `try`, and each error variant has its own test:

| Situation | Result |
| --- | --- |
| `fetch` throws | `Network` |
| Non-2xx with an `applicationError` body that decodes | `Application({status, error})` |
| Non-2xx with an `applicationError` body that fails the error codec | `InvalidResponse` |
| `applicationError` body from an endpoint that declares no errors | `InvalidResponse` |
| Any other non-2xx | `UnexpectedStatus` |
| Bad JSON, or a body that fails the response codec | `InvalidResponse` with the field path |
| A codec throws while encoding | `EncodeFailed`, not `Network` |
| Missing or non-scalar path param | `InvalidParams` |

**Are URLs built reliably? Yes, for the documented cases.**
- **Path prefix:** the base path prefix is kept (`https://x.dev/api/` plus `/accounts/:id` gives `/api/accounts/123`).
- **Slashes:** an extra slash on either side is tolerated.
- **Encoding:** values are percent-encoded (`a b/c?d` becomes `a%20b%2Fc%3Fd`).
- **Numbers:** number params are stringified.
- **Invalid base URL:** throws, because it's a configuration bug.
- **Not supported:** query strings and per-request headers (see Remaining work).

**Are successful and application-error responses validated? Yes.** Both decode through the contract's codecs before the caller sees a value.

## 6. Cloudflare compatibility

- **Runs under Wrangler: yes.** All 7 example tests pass over HTTP against `wrangler dev`. The suite covers:
  - a simple route
  - a typed GET, with codecs built at load
  - a typed error
  - a typed POST
  - an invalid body returning 400 with its path
  - the env binding through Hono's bearer auth
  - every client outcome
- **Codecs constructed at the right time: yes, and the check can fail.** A probe Worker builds a Sury codec during a request. It returns 200 under Node and 500 under workerd (`EvalError: Code generation from strings disallowed`). The example's 200s therefore show its codecs are built at load.
- **Route checking under Wrangler: yes.** A Worker importing a mismatched contract fails to start, with `Uncaught Error: Invalid route "/accounts/:accountId": ...`. Failure on a real deploy is still unverified, because deploying wasn't authorized.
- **No Node dependencies, no JS glue, no compatibility flags.** Confirmed by the dry-run bundle and the isolation check.

## 7. Repository quality

- **History.** The repository has 12 commits from an empty `git init` on `main`, one per milestone. No POC history was imported, and the POC repository was not modified.
- **No experimental artifacts.** There is no PPX, no codec experiments, no comparison project, and no POC assessment documents.
- **Hygiene sweep: clean.** No secrets, personal paths, POC branding or tracked build output. The example's secret is supplied with `--var` in tests and documented through `.dev.vars.example`.
- **Can a new contributor follow the README?** The README's install, build and test commands are exactly what `check:clean-build` runs on a fresh clone. The script was itself useful: it found that all 24 compile-fail tests failed in a fresh checkout, because their scratch directory was empty and therefore untracked. It's fixed. Every ReScript snippet in the README and the getting-started guide was compiled, and the guide's app was run end to end.

## 8. Remaining work before a first npm release

Ordered by impact:

1. **Verify packaging from tarballs in an outside project.** Never done. Run `npm pack` for all three packages, install them into a fresh ReScript project, then build and run. This will surface the next three items, and possibly more.
2. **Make `hono` and `sury` peer dependencies with ranges.** They are currently pinned dependencies (`hono: 4.13.13`), which would force a second copy of each on any app with a different version. The app owns those libraries. `@resapi/core` is depended on as `*`, which needs a real range.
3. **Ship LICENSE and README in each package.** `npm pack` currently includes only `package.json`, `rescript.json` and the sources.
4. **Decide the public surface with `.resi` files.** Internals are currently exported, for example `Client.buildPath`, `Client.encodeWith`, `RouteCheck.parse`, `Router.honoGet` and `Router.guard`. `docs/api.md` marks them as internal, but the compiler doesn't. Once a preview is out, removing them is a breaking change.
5. **Run CI once.** Push to a private GitHub repository, then fix whatever Linux or Node 22 surfaces. `test:worker` on Linux runners is the likeliest problem.
6. **Per-request client options.** There's no way to set headers (such as `Authorization`), query strings or an `AbortSignal` per call. The workaround is a custom `~fetch` that adds headers. It works, but it's the first thing an authenticated API needs.
7. **Success status and headers on typed endpoints.** Typed endpoints always answer 200, so there is no `201 Created` and no response headers short of middleware.
8. **PUT, PATCH and DELETE.** Deliberately left out. Likely the first feature request. Adding them is mechanical, because routing, body handling and the client already switch on `method`.

## 9. Decision points

**1. Is the package separation appropriate? Yes, keep three packages.**
- **The split is cheap:** one extra `open` in server code.
- **It buys a verified guarantee:** client bundles contain no Hono.
- **Merging Sury into core would break library independence,** and so would merging it into the Hono adapter. Sury is a codec choice, not a server choice.
- **The planned `@resapi/cloudflare` package turned out to be unnecessary** and was never created.

**2. Is the Hono adapter thin enough? Yes.**
- **What's left:** typed bindings (Context), five thin router functions, the exception guard, and typed-endpoint execution.
- **Nothing duplicates Hono behavior.** The POC's middleware module was removed in favor of Hono's built-ins, and both of its behavior overrides are gone.
- **Recommendation:** don't add wrappers per Hono feature. Document the one-external binding pattern instead (getting-started already does).

**3. Is the typed-error model ergonomic? Yes.**
- **Plain endpoints are unchanged.** Inference holds, and a bare `Error(NotFound)` resolves from the contract.
- **The cost is paid only by endpoints that declare errors,** at about 9 lines each.
- **`noError` makes undeclared failures a compile error** instead of a runtime convention.
- **Behavior change:** apps that relied on the POC's ad-hoc `notFound` must now declare it.
- **Keep the status mapping on the contract rather than in the codec.** `Codec.t` stays a pure JSON codec.

**4. Should path descriptors (`Path.t<'params>`) be introduced? No.**
- **The POC's comparison found that descriptors turn named record fields into positional tuples.** Swapped arguments then compile, which is worse than the mismatch they prevent.
- **Load-time route checking now catches every tested mismatch** for ordinary codecs.
- **The remaining gap is narrow:** a refining codec plus an extra route param it ignores. Revisit only if users report hitting it.

**5. Is resAPI ready for a public preview release? Not yet.** The smallest set of blockers is remaining-work items 1–5:
- tarball install verified in an outside project
- peer dependencies and version ranges
- per-package LICENSE and README
- `.resi` files for the public surface
- one green CI run

None of these needs design work. Items 6–8 can follow the preview, though item 6 (request headers) should be early.
