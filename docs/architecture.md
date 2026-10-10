# Architecture

resAPI rests on one idea: an HTTP endpoint is a value, the contract, that both server and client import. Everything else is an adapter around that value. This document records the design and the reasons behind each decision.

## Packages and dependencies

```text
        @resapi/core
           ▲     ▲
  @resapi/hono   @resapi/sury
```

- **`@resapi/core`** has `Codec`, `Endpoint`, `RouteCheck`, `Client` and `Fetch`. It depends only on the ReScript runtime and the Fetch API.
- **`@resapi/hono`** has `Router`, `EndpointHandler` and `Context`. It depends on core and Hono.
- **`@resapi/sury`** has `SuryCodec`. It depends on core and Sury.

These boundaries are checked on the compiled output by `scripts/check-isolation.mjs`. The check matters because of a ReScript detail: an `@module` external's import is emitted in the module that *calls* the external, not the one that declares it. A package's own files therefore don't show what an app ends up importing. The check walks the import graph from real entry points. The example's client module must not reach Hono or Cloudflare. Core must not reach any adapter, Sury, `node:` or `cloudflare:`. A positive control confirms that the Worker entry does reach Hono.

## Codecs

```rescript
type error = {path: array<string>, message: string}
type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}
```

Contracts depend on this record, not on a schema library. Sury is one implementation, and a hand-written record is another. `Codec.t` deliberately has no metadata, derivation or registry. The cost is that route checking must probe codecs rather than inspect them (see below).

`SuryCodec.make` compiles Sury's decoder and encoder immediately. Cloudflare Workers forbid `new Function` once a request is running, so codecs must be built at module top level. `scripts/test-worker.sh` proves workerd enforces this: building a codec during a request returns 200 under Node and 500 under workerd.

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

**Typed endpoints.** `EndpointHandler.make(contract, handler)` closes over the contract's types and returns a non-generic `route<'env>`. Endpoints of different types can therefore be registered on one router without a heterogeneous collection or any casts. Request handling runs in this order:

1. Decode the path params, without touching the body: `400 invalid_params`.
2. Parse the JSON body: `400 malformed_json`.
3. Decode the body: `400 invalid_body`.
4. Run the handler, then encode `Ok` or the declared error.

Any exception from a codec or handler is logged as the JS `Error` itself, so the stack is preserved. The client gets `500 {"error": {"kind": "internal", "message": "Internal Server Error"}}` and no detail.

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
| `Network(message)` | `fetch` itself failed |
| `UnexpectedStatus({status, body})` | Non-2xx without a declared error: framework errors, proxies, 500s |
| `InvalidResponse(Codec.error)` | The body broke the contract: bad JSON, a failed decode, or a malformed application error |
| `InvalidParams(message)` | A path param is missing or not a scalar. Usually caught earlier by route checking |
| `EncodeFailed(message)` | A codec threw while encoding the request |

## Client

`Client.call` (no body) and `Client.callWithBody` (POST) take the contract plus typed params and body. Keeping them separate gives a compile error for a missing or unexpected body without simulating overloads.

- **URLs.** `baseUrl` keeps its path prefix: `https://x.dev/api/` plus `/accounts/:id` gives `https://x.dev/api/accounts/123`. Param values are percent-encoded.
- **Error handling.** Only `fetch` itself sits inside a `try`. Codec failures and statuses are classified separately, so a codec bug is never reported as a network error. An invalid `baseUrl` throws, because it is a configuration bug rather than a request outcome.
- **Testing.** `~fetch` can be injected, so tests can run against a fake or call the router in-process.

## What was left out

The following were evaluated during prototyping or ruled out of scope: a route PPX, a native router, a custom middleware lifecycle that overrides Hono, path-descriptor values (`Path.t<'params>`), OpenAPI generation, other HTTP methods, multiple success responses, and storage or auth integrations.
