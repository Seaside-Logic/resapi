# Changelog

All four packages (`@resapi/core`, `@resapi/hono`, `@resapi/express`, `@resapi/sury`) are released together with the same version.

## 0.3.0 (preview)

Adds PUT endpoints.

### Breaking changes

- **`Endpoint.method`** has a new `Put` case. A `switch` on it that lists every case needs a `Put` arm.

### Added

- **PUT contracts:** `Endpoint.put(path, ~params, ~body, ~response)`, with the same checks as `post`. The client sends a JSON body, and both adapters read it as they do for POST (Express mounts PUT routes behind the same raw-text parser).
- **`Router.put`** (both adapters) for plain routes.

### Migrating from 0.2.0

- Add a `Put` arm to any exhaustive match on `Endpoint.method`. Nothing else changes.

### Known limitations

The 0.2.0 limitations still apply, except that PUT is now supported. PATCH and DELETE are planned.

## 0.2.0 (preview)

These changes come from testing 0.1.0 against a real application (WealthJack) and a second, deliberately different Express service. The main one: auth is ordinary Hono or Express middleware, and resAPI adds two small helpers so the rejection and the signed-in user are typed on both ends.

### Breaking changes

- **`Client.error`:** `InvalidParams` and `EncodeFailed` are gone, and there's a new `Unauthorized({status, reason})` case. A param that can't fill the path, or a codec that throws while encoding, now rejects the call with a JS `Error`, as an invalid `baseUrl` already did.
- **401 and 403 responses** that aren't declared errors are `Unauthorized`, not `UnexpectedStatus`.
- **`ResApi.Fetch` mirrors `@rescript/webapi`,** so code written against it keeps compiling when it becomes re-exports of webapi. The renames:
  - `Response.text(string)` → `Response.fromString`
  - `Response.json(json, ~init)` → `Response.jsonR(~data, ~init)`
  - `Response.readText` → `Response.text`
  - `Response.status`/`ok` → record fields
  - `Response.header`/`setHeader` → `Headers.get` (returns `Null.t`) and `Headers.set(~name, ~value)` on `response.headers`
  - `Request.make` → `Request.fromURL` (init: `headers: HeadersInit.t`, `body: Nullable.t<BodyInit.t>`)
  - `AbortController.signal(c)` → `c.signal`

### Added

- **Auth as middleware:**
  - `Reject.unauthenticated`/`forbidden` (both adapters) answer in a shape the client reads as `Unauthorized` with a reason.
  - `ResApi.Key` with `Context.set/get/getOrThrow` (Hono) and `Req.set/get/getOrThrow` (Express) pass typed values, such as the signed-in user, from middleware to handlers. On Express a key is a property on `req`, so its name mustn't be one of Express's own.
- **`Client.message`:** English defaults for every client error except declared errors.
- **Codec combinators:**
  - primitives: `string`, `int`, `float`, `bool`
  - containers: `enum`, `array`, `option`, `refine`
  - records: `object`/`field`
- **Routing beside typed endpoints:**
  - `Router.all` (both adapters)
  - `Router.notFound` and `Context.request` (Hono)
  - `Endpoint.any` with `Router.assertRegistered`, a test-time check that every contract is registered
- **`Dispatch.errorResponse`**, the framework error body, for adapters (`Dispatch` stays unstable).
- **Docs:** a Hono guide beside the Express one (both now part of the shared guides, starting with [Getting started](site/content/getting-started.md)), a compiled auth-middleware example in Getting started, and a section on reading type errors.

### Migrating from 0.1.0

- **Client matches:** remove the `InvalidParams` and `EncodeFailed` arms. Handle `Unauthorized({status, reason})` where 401/403 used to land in `UnexpectedStatus`, or end the match with `Error(error) => Client.message(error, ~declared=...)`.
- **Programmer errors:** a call with a missing path param or a throwing codec now rejects instead of resolving to `Error(...)`. Let it surface as the bug it is, or catch it where you call.
- **Fetch:** apply the renames above. Bindings to other libraries that used `ResApi.Fetch` types keep working once their calls are renamed.
- **Auth:** if handlers checked the session themselves, that still works. To move it into middleware, see [Middleware and auth](site/content/middleware.md).

### Tested with

ReScript 12.3.1, Node 22 and 24, Hono 4.13, Express 5.2, Sury 11.0, and Cloudflare Workers through Wrangler's local runtime.

### Known limitations

The 0.1.0 limitations still apply. With auth in middleware, the compiler doesn't check that each endpoint is behind it: a typed endpoint on a path no middleware covers compiles, and `getOrThrow` turns the missing value into a logged 500.

## 0.1.0 (preview)

The first public release. resAPI defines an HTTP endpoint once, as a contract, and uses it on both the server and the client, with compile-time checking and runtime validation.

### Packages

- `@resapi/core`: contracts (`Endpoint`), codecs (`Codec`), route checking (`RouteCheck`), the typed `Client`, Fetch bindings, and the server pipeline shared by the adapters (`Dispatch`, unstable).
- `@resapi/hono`: runs contracts on Hono, including Cloudflare Workers.
- `@resapi/express`: runs contracts on Express 5.
- `@resapi/sury`: Sury schemas as codecs.

### Features

- GET and POST contracts with typed path params, request body, response and declared application errors.
- Server-side decoding of params and body before the handler runs, with structured 400s (`invalid_params`, `malformed_json`, `invalid_body`).
- Typed application errors with per-error HTTP statuses, kept separate from framework errors on the wire and on the client.
- Unexpected exceptions are logged and answered with a 500 that reveals nothing.
- A typed client with request headers (per call and per client), cancellation via `AbortSignal`, and distinct error variants for each kind of failure.
- Route params are checked against the params codec when a contract is built, so a mismatch stops the app from starting.
- Native Hono and Express middleware.

### Tested with

ReScript 12.3.1, Node 22 and 24, Hono 4.13, Express 5.2, Sury 11.0, and Cloudflare Workers through Wrangler's local runtime. Other versions within the declared peer ranges are expected to work but haven't been tested.

### Known limitations

- Only GET and POST. PUT, PATCH and DELETE are planned.
- No typed query parameters.
- A successful typed response is always 200, with no custom success status or response headers.
- Only JSON bodies.
- Express 4 is not supported.
- `Dispatch` is public only because the adapters need it. It may change in any release.
- Unexpected exceptions are logged with `console.error`. There is no hook for an error reporter yet.

### Provenance

0.1.0 was published from a maintainer's machine to create the packages on npm, so it has no provenance attestation. Later versions are published by the tag-triggered GitHub workflow with provenance.

### Stability

This is a preview. The API may change in 0.x minor releases, and each change will be listed here with migration notes.
