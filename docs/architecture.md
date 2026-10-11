# Architecture

resAPI rests on one idea: an HTTP endpoint is a value, the contract, that both server and client import. Everything else is an adapter around that value. This document records the design and the reasons behind each decision.

## Packages and dependencies

```text
                 @resapi/core
           ▲          ▲          ▲
  @resapi/hono  @resapi/express  @resapi/sury
```

- **`@resapi/core`** has `Codec`, `Endpoint`, `RouteCheck`, `Client`, `Fetch` and `Dispatch` (the server pipeline shared by adapters, see below). It depends only on the ReScript runtime and the Fetch API.
- **`@resapi/hono`** has `Router`, `EndpointHandler` and `Context`. It depends on core and Hono.
- **`@resapi/express`** has `Router`, `EndpointHandler`, `Req` and `Res`. It depends on core and Express.
- **`@resapi/sury`** has `SuryCodec`. It depends on core and Sury.

These boundaries are checked on the compiled output by `scripts/check-isolation.mjs`. The check matters because of a ReScript detail: an `@module` external's import is emitted in the module that *calls* the external, not the one that declares it. A package's own files therefore don't show what an app ends up importing. The check walks the import graph from real entry points. Each example's client module must not reach its server framework. Core must not reach any adapter, Sury, `node:` or `cloudflare:`, and no adapter reaches another. Positive controls confirm that the Worker entry reaches Hono and the Express example's server entry reaches Express.

### Public interfaces

Every module with internals has a `.resi`. These files are the compatibility boundary, and anything they leave out is internal. `Endpoint.t` and `EndpointHandler.route` are `private` records: adapters can read their fields, but only `Endpoint.get`/`post` can build a contract, so no contract skips route checking. `scripts/check-packages.sh` packs each package and installs it into a fresh project outside the repo, so the packages are also tested the way users get them.

**Decision: `Dispatch` is public but unstable.**
- *Problem:* both adapters need `Dispatch.run`, but it isn't meant as an API yet.
- *Options:* make it package-internal, make it a documented extension point, or make it public but unstable.
- *Decision:* public, marked unstable in `Dispatch.resi` and the API reference.
- *Reason:* ReScript can't make a module visible to other packages without exposing it to everyone. Promising stability before any third-party adapter exists would be premature.
- *Consequences:* `Dispatch` can change in any 0.x release, and third-party adapters that use it do so at their own risk.

## Codecs

```rescript
type error = {path: array<string>, message: string}
type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}
```

Contracts depend on this record, not on a schema library. Sury is one implementation, and a hand-written record is another. `Codec.t` deliberately has no metadata, derivation or registry. The cost is that route checking must probe codecs rather than inspect them (see below).

`SuryCodec.make` compiles Sury's decoder and encoder immediately. Cloudflare Workers forbid `new Function` once a request is running, so codecs must be built at module top level. `scripts/test-worker.sh` proves workerd enforces this: building a codec during a request returns 200 under Node and 500 under workerd.

**Combinators.** `Codec` has a small combinator set (primitives, `enum`, `array`, `option`, `refine`, `object`/`field`). `object` decodes into a record literal: `field` signals a failure with an exception that `object` catches, so a field left out of the literal is a compile error, and nothing escapes. `enum` takes the values and their `toString`, so with `@as` variants and `(v :> string)` the wire names are written once and checked by the compiler.

**Fetch types.** `ResApi.Fetch` is a strict subset of `@rescript/webapi`'s Fetch bindings: same names, labels and record fields. When ReScript 13 and webapi are stable, the module becomes re-exports and user code keeps compiling. Until then, bind other libraries' Fetch functions against `ResApi.Fetch` types. webapi binds union-typed init values (`HeadersInit`, `BodyInit`) with `%identity` constructors, and the mirror does the same. It's the one place resAPI allows them.

**Wrapping policy.** The adapters wrap what typed endpoints need, plus the routing beside them (`Router.all`, and `Router.notFound` on Hono), and give typed access to the framework's request (`Context.request`). Anything else binds with one external against `Router.t`, which *is* the framework app. `Endpoint.any` erases a contract's types, so a list of every contract can be checked with `Router.assertRegistered` in a test.

## Contracts

```rescript
type t<'params, 'body, 'response, 'error> = {
  method, path, paramsCodec, bodyCodec, responseCodec, errorCodec, errorStatus: 'error => int,
}
```

`Endpoint.get(path, ~params, ~response)` fixes `'body = unit`, and `Endpoint.post` adds `~body`. Only GET and POST exist so far. Other methods will be added when an application needs them.

The type parameters carry all the checking. A handler's input and output types, and a client call's params, body and result types, are all read off the contract, so a mismatch is a compile error at the call site. No casts are involved.

## Route checking at construction

The contract's path and its params codec describe the same names twice, so they can disagree. A compile-time fix (a PPX that generates the params type from the route) was prototyped and rejected, because maintaining native PPX binaries outweighed the benefit. Instead, `Endpoint.get`/`post` call `RouteCheck` and throw on a mismatch. Contracts are top-level values, so a bad contract stops the module from loading. Under Wrangler, the Worker fails to start with `Invalid route "<path>": ...`.

`RouteCheck` works with any codec by probing it:

1. Parse the route. Only literal segments and `:name` params are understood. Hono syntax such as `*`, `:id{regex}` or `:id?` is rejected as unsupported, not passed off as validated. Duplicate names are rejected.
2. Decode an object with every route param set to `"x"`.
   - A decode error at a field the route lacks is a mismatch.
   - A decode error at a field the route *has* means the codec refines strings (a UUID or an int, say). That makes the result `CannotValidate`, which is accepted.
3. Otherwise, encode the decoded value and compare its keys with the route's params in both directions.

**Known limit:** for a refining codec, a route param the codec ignores goes unnoticed. A codec field missing from the route is caught only if it is the first decode error. `CannotValidate` is accepted silently rather than logged, because a log line would print on every Worker start. `RouteCheck.check` returns the outcome for anyone who wants to assert on it.

## Server adapter: Hono

Hono provides routing, path matching and Fetch integration. resAPI uses Hono's features rather than hiding them:

- **`Router.t<'env>` is the Hono app.** A Worker can `let default = app`, with no JS glue. Any Hono API that resAPI doesn't wrap can be bound against `Router.t` with one more external. `'env` is a phantom type for the Worker's bindings, read with `Context.env`.
- **Native middleware.** `Router.middleware<'env>` is Hono's `(c, next)` shape, returning `option<Response>`. Hono's built-in middleware (`hono/logger`, `hono/bearer-auth`, `hono/cors`, ...) binds with a single external, and the tests cover logger and bearer-auth. Middleware sees Hono's native semantics. A handler's exception has already become a 500 response by the time outer middleware runs, so middleware can't catch it.
- **One adaptation.** Hono's error handling (`compose`, `onError`) only handles values that are `instanceof Error` and rethrows anything else out of `app.fetch`. Raw ReScript exceptions are plain objects, so without help they would escape and fail the request with no response. `Router.get`/`post`/`use` therefore catch non-`Error` exceptions and rethrow them as JS `Error`s. JS errors, including Hono's `HTTPException`, pass through untouched, and Hono's default `onError` (log, then a plain 500) handles both. This relies only on documented Hono behaviour.
- **Versions.** Hono 4 (tested on 4.13.13).

**Typed endpoints.** `EndpointHandler.make(contract, handler)` closes over the contract's types and returns a non-generic `route<'env>`. Endpoints of different types can therefore be registered on one router without a heterogeneous collection or any casts. The request pipeline is core's `Dispatch.run`, which every adapter shares, so the wire format has one definition. The adapter supplies the raw params and body and sends the `{status, body}` it gets back. Request handling runs in this order:

1. Decode the path params, without touching the body: `400 invalid_params`.
2. Parse the JSON body: `400 malformed_json`.
3. Decode the body: `400 invalid_body`.
4. Run the handler, then encode `Ok` or the declared error.

Any exception from a codec or handler is logged as the JS `Error` itself, so the stack is preserved. The client gets `500 {"error": {"kind": "internal", "message": "Internal Server Error"}}` and no detail.

## Server adapter: Express

`@resapi/express` follows the Hono adapter's shape on Express 5:

- **`Router.t` is the Express app**, so `app.listen` and any unwrapped Express API are one external away. It has no `'env` parameter, because Express has no bindings object; read configuration from `process.env`.
- **Native handlers and middleware.** Plain routes take `(req, res) => promise<unit>`. Middleware is Express's `(req, res, next) => unit`, so `express.json()`, `express.static` and similar bind with a single external.
- **Errors.** Express 5 passes a rejected handler promise to its error handler. As on Hono, `Router.get`/`post`/`use` rethrow raw ReScript exceptions as JS `Error`s, here so that Express's handler logs a stack instead of `[object Object]`. Express's default handler shows the stack in the response body unless `NODE_ENV=production`; that is Express's behaviour, and typed endpoints never reach it.
- **Request bodies.** `Router.register` mounts POST endpoints behind `express.text({type: () => true})`, so `Dispatch` sees the raw body and reports `malformed_json` exactly as on Hono. If an upstream `express.json()` has already parsed the body, the parsed value is used.
- **Body parsers and auth.** `register` mounts its body parser on each route, so `Router.use` middleware, including auth, runs before any body is read. An upstream body parser mounted globally answers its own failures before your auth middleware, which is why the guide says not to.

Usage details (body parsers and size limits, content types, request-scoped values, supported versions) are in the [Express guide](express.md).

## Auth is middleware

resAPI doesn't model auth in contracts. Hono and Express already protect paths with middleware (`app.use("/api/*", bearerAuth({token}))`), and that runs before resAPI's pipeline, so it checks auth before params and body, and protects everything under a prefix by default. resAPI adds two small helpers:

- **`Reject`** answers 401/403 in the framework error shape, so the client can tell an auth rejection (`Unauthorized`, with a reason) from other failures. The client classifies any 401/403 that isn't a declared error as `Unauthorized`, so third-party middleware works too, just without a reason.
- **`Key`** gives a request value a type. It's stored and read under the framework's own name (`c.set`/`c.get`, or a property on `req`), so it also reads what third-party middleware sets. The type is a declaration, like any binding.

**Considered and dropped: declared guards.** A guard declaration in each contract, an implementation per server, and a separate client error case. It made forgetting auth a compile error, and gave typed auth errors per app. Measured on WealthJack, it added four concepts, a fifth type parameter on `Endpoint.t` and about 25 lines, while protection by path already gives the default-protected behaviour apps expect. The trade made here: the compiler no longer checks per endpoint that auth is wired up, and auth failures are one built-in type (`Unauthorized({status, reason})`) rather than an app-defined one.

## Typed application errors

Endpoints declare their expected failures:

```rescript
Endpoint.get(...)->Endpoint.withErrors(errorCodec, ~status=error => switch error { | NotFound => 404 })
```

- **`noError`.** `get`/`post` produce `'error = Endpoint.noError`, an abstract type with no values, so a handler for a plain endpoint cannot return `Error` at all. `withErrors` only accepts a `noError` contract, so errors are declared once.
- **Where the status lives.** The status mapping is on the contract, not in the codec, so `Codec.t` stays a pure JSON codec. A status outside 4xx/5xx is treated as a server bug and becomes an internal 500.
- **Wire format.** The response has the declared status and a body of `{"applicationError": <encoded error>}`. Framework errors use `{"error": {...}}`, so the two cannot be confused.
- **Client side.** A non-2xx body with an `applicationError` key must decode with the contract's error codec. A body that fails to decode, or one from an endpoint that declares no errors, is `InvalidResponse`. Any other non-2xx body is `UnexpectedStatus`.

Error categories stay distinct on the client:

| Variant | Meaning |
| --- | --- |
| `Application({status, error})` | A declared error, decoded and typed |
| `Unauthorized({status, reason})` | A 401/403 that isn't a declared error, from any middleware |
| `Network(message)` | `fetch` itself failed |
| `Aborted` | The call's `~signal` aborted or timed out |
| `UnexpectedStatus({status, body})` | Non-2xx without a declared error: framework errors, proxies, 500s |
| `InvalidResponse(Codec.error)` | The body broke the contract: bad JSON, a failed decode, or a malformed application error |

Bugs in the calling code (a param that can't fill the path, a codec that throws, an invalid `baseUrl`) throw instead of returning an error.

## Client

`Client.call` (no body) and `Client.callWithBody` (POST) take the contract plus typed params and body. Keeping them separate gives a compile error for a missing or unexpected body without simulating overloads.

- **URLs.** `baseUrl` keeps its path prefix: `https://x.dev/api/` plus `/accounts/:id` gives `https://x.dev/api/accounts/123`. Param values are percent-encoded.
- **Error handling.** Only `fetch` itself sits inside a `try`. Codec failures and statuses are classified separately, so a codec bug is never reported as a network error. An invalid `baseUrl` throws, because it is a configuration bug rather than a request outcome.
- **Testing.** `~fetch` can be injected, so tests can run against a fake or call the router in-process.
- **Request options.** Headers merge as client defaults, then `content-type`, then per-call headers, with names lowercased so a later value replaces an earlier one instead of Fetch joining them. Cancellation is the Fetch `AbortSignal`, not a resAPI mechanism. An abort is reported as `Aborted`, separately from `Network`, because the caller chose it.

The full list of failures and their wire formats is in [Errors](errors.md).

## What was left out

The following were evaluated during prototyping or ruled out of scope: a route PPX, a native router, a custom middleware lifecycle that overrides Hono, path-descriptor values (`Path.t<'params>`), OpenAPI generation, other HTTP methods, multiple success responses, and storage or auth integrations.
