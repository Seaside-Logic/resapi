# Architecture

In resAPI, each HTTP endpoint is defined by a contract: a value shared by the server and client. Adapters connect that contract to a server framework or codec library. This document explains the design and the decisions behind it.

## Packages and dependencies

```text
                 @resapi/core
           ▲          ▲          ▲
  @resapi/hono  @resapi/express  @resapi/sury
```

- **`@resapi/core`** provides `Codec`, `Endpoint`, `RouteCheck`, `Client`, `Fetch`, and `Dispatch`, the shared server request pipeline described below. It depends only on the ReScript runtime and the Fetch API.
- **`@resapi/hono`** provides `Router`, `EndpointHandler`, and `Context`. It depends on core and Hono.
- **`@resapi/express`** provides `Router`, `EndpointHandler`, `Req`, and `Res`. It depends on core and Express.
- **`@resapi/sury`** provides `SuryCodec`. It depends on core and Sury.

`scripts/check-isolation.mjs` checks these boundaries in the compiled output. ReScript emits an `@module` external's import in the module that *calls* it, so inspecting a package's own files isn't enough to determine what an application imports. The script follows the import graph from actual entry points. It checks that each example's client cannot import its server framework, that core cannot import any adapter, Sury, `node:`, or `cloudflare:`, and that adapters cannot import one another. It also confirms that the Worker entry does reach Hono and the Express server entry does reach Express, to verify that the graph traversal detects those dependencies.

### Public interfaces

Every module with internal implementation details has a `.resi` file defining its public interface. Anything omitted from that interface is internal. `Endpoint.t` and `EndpointHandler.route` are `private` records: adapters can read their fields, but contracts can only be created through `Endpoint.get` or `Endpoint.post`. This ensures every contract goes through route checking. To test the published package layout, `scripts/check-packages.sh` packs each package and installs it in a fresh project outside the repository.

**Decision: `Dispatch` is public but unstable.**

- *Problem:* both adapters need `Dispatch.run`, but it isn't ready to be a stable public API.
- *Options:* make it package-internal, make it a documented extension point, or make it public but unstable.
- *Decision:* expose it publicly and mark it unstable in `Dispatch.resi` and the API reference.
- *Reason:* ReScript cannot expose a module only to selected packages. There is also no third-party adapter yet to help establish what a stable interface should provide.
- *Consequences:* `Dispatch` can change in any 0.x release. Third-party adapters that use it may need updates between releases.

## Codecs

```rescript
type error = {path: array<string>, message: string}
type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}
```

Contracts use this record type without depending on a particular schema library. You can create a codec with Sury or write one by hand. `Codec.t` has no metadata, derivation, or registry. As a result, route checking must test a codec with sample data instead of inspecting its structure, as described below.

`SuryCodec.make` compiles Sury's decoder and encoder when it is called. Cloudflare Workers prohibit `new Function` during a request, so codecs must be created at module top level. `scripts/test-worker.sh` checks this restriction: a request that builds a codec returns 200 under Node and 500 under workerd.

**Combinators.** `Codec` provides primitives and a small set of combinators: `enum`, `array`, `option`, `refine`, and `object`/`field`. With `object`, the decoder builds a record literal, so the compiler catches missing record fields. If a `field` fails to decode, it raises an exception that `object` catches and turns into a decode error. `enum` takes a list of values and a `toString` function. For `@as` variants, `(v :> string)` lets you define the JSON names once in the type and have the compiler check the conversion.

**Fetch types.** `ResApi.Fetch` provides a subset of `@rescript/webapi`'s Fetch bindings with the same names, labels, and record fields. The plan is to re-export webapi's bindings when ReScript 13 and webapi are stable, preserving compatibility with existing code. Until then, use `ResApi.Fetch` types when binding other libraries' Fetch functions. Like webapi, this module uses `%identity` constructors for union-typed initialization values (`HeadersInit` and `BodyInit`). This is the only place resAPI allows those constructors.

**Wrapping policy.** The adapters wrap the APIs needed for typed endpoints and related routing, including `Router.all` and Hono's `Router.notFound`. They also expose the original Hono request through `Context.request`. For other framework APIs, define an external that accepts `Router.t`, which is the framework app itself. Use `Endpoint.any` to put contracts with different types in one list, then check that list with `Router.assertRegistered` in a test.

## Contracts

```rescript
type t<'params, 'body, 'response, 'error> = {
  method, path, paramsCodec, bodyCodec, responseCodec, errorCodec, errorStatus: 'error => int,
}
```

`Endpoint.get(path, ~params, ~response)` sets the body type to `unit`. `Endpoint.post` also accepts a `~body` codec. GET and POST are currently the only supported methods; others will be added when an application needs them.

The contract's type parameters determine the handler's input and output types and the client's parameter, body, and result types. A mismatch produces a compile error where the handler or client call is defined. This checking requires no casts.

## Route checking at construction

The route string and parameter codec both describe the path parameter names, so they can disagree. A prototype PPX generated the parameter type from the route at compile time, but the cost of maintaining native PPX binaries outweighed the benefit. Instead, `Endpoint.get` and `Endpoint.post` call `RouteCheck` and throw if they find a mismatch. Because contracts are defined at module top level, an invalid contract prevents the module from loading. Under Wrangler, the Worker fails to start with `Invalid route "<path>": ...`.

`RouteCheck` tests codecs with sample data, so it can work without codec metadata:

1. Parse the route. Only literal segments and `:name` parameters are supported. Duplicate names and Hono syntax such as `*`, `:id{regex}`, or `:id?` are rejected.
2. Decode an object with every route parameter set to `"x"`.
   - If decoding fails at a field missing from the route, the route and codec do not match.
   - If decoding fails at an existing route parameter, the codec may require a more specific value, such as a UUID or integer. The result is `CannotValidate`, which is accepted.
3. If decoding succeeds, encode the value and check that its keys match the route parameter names exactly.

**Known limitation:** when a codec rejects the sample value, the check cannot detect route parameters that the codec ignores. It detects a codec field missing from the route only if that field causes the first decode error. `CannotValidate` is accepted without logging to avoid repeating a message on every Worker start. Tests can call `RouteCheck.check` to inspect and assert on the result.

## Server adapter: Hono

Hono provides routing, path matching, and Fetch integration. The adapter exposes these features directly:

- **`Router.t<'env>` is the Hono app.** Export it from a Worker with `let default = app`. To use an unwrapped Hono API, define an external that accepts `Router.t`. The phantom type parameter `'env` describes the Worker's bindings, which you read with `Context.env`.
- **Native middleware.** `Router.middleware<'env>` uses Hono's `(c, next)` signature and returns `option<Response>`. Built-in middleware such as `hono/logger`, `hono/bearer-auth`, and `hono/cors` can be bound with a single external. Tests cover logger and bearer-auth. Hono's middleware behavior is preserved: by the time control returns to outer middleware, a handler exception has already become a response, so middleware cannot catch the original exception.
- **Exception conversion.** Hono's error handling (`compose`, `onError`) only handles values that are `instanceof Error`. Other values are rethrown from `app.fetch`. Raw ReScript exceptions are plain objects, so they would escape without a response. `Router.get`, `Router.post`, and `Router.use` catch these exceptions and rethrow them as JavaScript `Error` objects. Existing JavaScript errors, including Hono's `HTTPException`, pass through unchanged. Hono can then handle both using its documented error handling.
- **Versions.** The adapter supports Hono 4 and is tested with version 4.13.13.

**Typed endpoints.** `EndpointHandler.make(contract, handler)` captures the contract's types and returns a `route<'env>` that no longer exposes the endpoint's type parameters. This lets one router register endpoints with different types without casts or a heterogeneous collection. Both adapters use core's `Dispatch.run` for request processing, so the response format is defined in one place. The adapter supplies raw parameters and the body, then sends the returned `{status, body}` response. Processing follows this order:

1. Decode the path parameters before reading the body. Invalid parameters return `400 invalid_params`.
2. Parse the body as JSON. Invalid JSON returns `400 malformed_json`.
3. Decode the body. A decode failure returns `400 invalid_body`.
4. Run the handler, then encode its `Ok` result or declared error.

If a codec or handler throws a JavaScript `Error`, resAPI logs the original object to preserve its stack trace. The client receives `500 {"error": {"kind": "internal", "message": "Internal Server Error"}}` without the exception details.

For examples, choose Hono in the guides. [Getting started](getting-started.md) covers Workers and `'env` annotations, [Middleware and auth](middleware.md) covers middleware, and [Request bodies](request-bodies.md) explains body size limits.

## Server adapter: Express

`@resapi/express` provides the same contract-based request handling on Express 5:

- **`Router.t` is the Express app.** You can bind `app.listen` or any other unwrapped Express API with an external. There is no `'env` parameter because Express has no bindings object. Read runtime configuration from `process.env`.
- **Native handlers and middleware.** Plain route handlers use `(req, res) => promise<unit>`, and middleware uses `(req, res, next) => unit`. Built-in middleware such as `express.json()` and `express.static` can be bound with a single external.
- **Errors.** Express 5 forwards rejected handler promises to its error handler. `Router.get`, `Router.post`, and `Router.use` convert raw ReScript exceptions to JavaScript `Error` objects so Express can log a stack trace. Express's default error handler includes the stack in the response unless `NODE_ENV=production`. Typed endpoint exceptions are handled by resAPI before they reach that handler.
- **Request bodies.** `Router.register` adds `express.text({type: () => true})` before each POST handler. This gives `Dispatch` the raw body so it can report `malformed_json` in the same way as on Hono. If an earlier `express.json()` parser has already read the body, resAPI uses the parsed value.
- **Body parsers and auth.** Because `register` adds its parser to each route, middleware registered before that route can check auth before the body is read. A global body parser registered before auth handles parser failures first. The guide therefore recommends scoping body parsers to the routes that need them.

For examples, choose Express in the guides. [Getting started](getting-started.md) lists supported versions, [Middleware and auth](middleware.md) explains how to pass values through a request, and [Request bodies](request-bodies.md) covers parsers, size limits, and content types.

## Auth is middleware

Auth is configured through server middleware. Hono and Express can protect a path prefix with middleware, such as `app.use("/api/*", bearerAuth({token}))`. Registered before the routes, it checks auth before resAPI validates parameters or reads the body, and protects all routes under that prefix. resAPI provides two helpers:

- **`Reject`** sends a 401 or 403 in resAPI's error format, allowing the client to report `Unauthorized` with an optional reason. The client also classifies 401/403 responses from third-party middleware as `Unauthorized` unless they contain a declared application error.
- **`Key`** gives a stored request value a type. Values use the framework's own storage: `c.set`/`c.get` on Hono, or a property on `req` in Express. Keys can therefore read values set by third-party middleware too. As with an external binding, the declared type isn't checked at runtime.

**Considered and dropped: declared guards.** A prototype declared guards in each contract, implemented them on each server, and added a separate client error case. It caught missing auth at compile time and supported application-specific auth error types. In WealthJack, however, it added four concepts, a fifth type parameter to `Endpoint.t`, and about 25 lines of code. Protecting a path prefix already covered the application's needs. The chosen design is simpler, but the compiler no longer checks that each endpoint has auth middleware, and auth failures use the built-in `Unauthorized({status, reason})` type.

## Typed application errors

Endpoints declare their expected failures:

```rescript
Endpoint.get(...)->Endpoint.withErrors(errorCodec, ~status=error => switch error { | NotFound => 404 })
```

- **`noError`.** `get` and `post` set the error type to `Endpoint.noError`, an abstract type with no values. Until errors are declared, the handler cannot return `Error`. `withErrors` only accepts a `noError` contract, so errors can be declared only once.
- **Status mapping.** The contract maps each application error to an HTTP status, keeping `Codec.t` focused on JSON encoding and decoding. A status outside 400–599 is treated as a server bug and returns an internal 500.
- **Response format.** The response uses the declared status and a body of `{"applicationError": <encoded error>}`. resAPI's validation and internal errors use `{"error": {...}}`, so the client can distinguish them.
- **Client handling.** A body with an `applicationError` key must decode with the contract's error codec. If decoding fails, or the endpoint declares no errors, the result is `InvalidResponse`. Other non-2xx responses become `Unauthorized` for status 401/403, or `UnexpectedStatus` otherwise.

Error categories stay distinct on the client:

| Variant | Meaning |
| --- | --- |
| `Application({status, error})` | A declared application error decoded with the contract's error codec |
| `Unauthorized({status, reason})` | A 401 or 403 response that is not a declared application error |
| `Network(message)` | The `fetch` call failed |
| `Aborted` | The call's `~signal` was aborted or timed out |
| `UnexpectedStatus({status, body})` | Another non-2xx response, such as a framework error, proxy failure, or internal server error |
| `InvalidResponse(Codec.error)` | The response violates the contract: invalid JSON, a decode failure, or an invalid application error |

Bugs in the calling code reject the promise instead of returning an error result. Examples include a parameter that cannot be inserted into the path, a codec that throws, or an invalid `baseUrl`.

## Client

`Client.call` accepts a contract without a body, while `Client.callWithBody` accepts a POST contract and its body. Both take typed path parameters. Separate functions let the compiler catch missing or unexpected bodies without simulating overloads.

- **URLs.** The client preserves the path prefix in `baseUrl`. For example, `https://x.dev/api/` combined with `/accounts/:id` produces `https://x.dev/api/accounts/123`. Parameter values are percent-encoded.
- **Error handling.** Only the `fetch` call is inside the network error handler. Codec failures and HTTP statuses are classified separately, so codec bugs are never reported as network errors. An invalid `baseUrl` throws because it is a configuration error.
- **Testing.** Pass a custom `~fetch` function to use a fake in tests or call the router directly in the same process.
- **Request options.** Header names are lowercased before merging so later values replace earlier ones instead of Fetch joining them. For JSON requests, headers merge in this order: client defaults, resAPI's `content-type`, then per-call headers. Cancellation uses the standard Fetch `AbortSignal`. A cancelled or timed-out call returns `Aborted`, separately from `Network`.

See [Errors](errors.md) for all failure types and response formats.

## What was left out

Features considered during prototyping or left outside the current scope include a route PPX, a native router, a custom middleware lifecycle, path descriptor values (`Path.t<'params>`), OpenAPI generation, additional HTTP methods, multiple success responses, and storage or auth integrations.
