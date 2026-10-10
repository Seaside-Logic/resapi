# Changelog

All four packages (`@resapi/core`, `@resapi/hono`, `@resapi/express`, `@resapi/sury`) are released together with the same version.

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

### Stability

This is a preview. The API may change in 0.x minor releases, and each change will be listed here with migration notes.
