# API reference

This page lists the public API. Some modules export helpers that aren't listed here, such as `Client.buildPath`, `RouteCheck.parse` and `Router.honoGet`. Those are internal and may change without notice.

## `@resapi/core` (namespace `ResApi`)

### `Codec`

```rescript
type error = {path: array<string>, message: string}
type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}

let unit: t<unit>  // decodes anything to (), encodes to {}
```

Use `Codec.unit` as `~params` for routes without path params. A codec's `path` names the field that failed, as in `["owner", "name"]` or `["tags", "1"]`.

### `Endpoint`

```rescript
type method = Get | Post
type noError  // no values: the error type of endpoints that declare none

type t<'params, 'body, 'response, 'error> = {
  method: method,
  path: string,
  paramsCodec: Codec.t<'params>,
  bodyCodec: Codec.t<'body>,
  responseCodec: Codec.t<'response>,
  errorCodec: Codec.t<'error>,
  errorStatus: 'error => int,
}

let get: (string, ~params: Codec.t<'p>, ~response: Codec.t<'r>) => t<'p, unit, 'r, noError>
let post: (string, ~params: Codec.t<'p>, ~body: Codec.t<'b>, ~response: Codec.t<'r>) => t<'p, 'b, 'r, noError>
let withErrors: (t<'p, 'b, 'r, noError>, Codec.t<'e>, ~status: 'e => int) => t<'p, 'b, 'r, 'e>
```

- **Route checking:** `get` and `post` throw if the route's `:params` don't match the params codec (see `RouteCheck`). Define contracts at module top level, so a mismatch fails at load.
- **`withErrors`:** declares the endpoint's application errors. `~status` must return 400–599.

### `RouteCheck`

```rescript
type outcome = Valid | Invalid(string) | CannotValidate(string)

let check: (string, Codec.t<'p>) => outcome
let assertValid: (string, Codec.t<'p>) => unit  // throws on Invalid
```

`Endpoint.get` and `post` call `assertValid`. `check` is public so tests can assert on the outcome. A `CannotValidate` result means a codec rejected the probe value at a real route param, for example because it refines strings. See the [architecture document](architecture.md#route-checking-at-construction) for the probe and its limits.

### `Client`

```rescript
type t
type error<'e> =
  | Application({status: int, error: 'e})
  | Network(string)
  | UnexpectedStatus({status: int, body: string})
  | InvalidResponse(Codec.error)
  | InvalidParams(string)
  | EncodeFailed(string)

let make: (~baseUrl: string, ~fetch: Fetch.Request.t => promise<Fetch.Response.t>=?) => t

let call: (t, Endpoint.t<'p, unit, 'r, 'e>, ~params: 'p) => promise<result<'r, error<'e>>>
let callWithBody: (t, Endpoint.t<'p, 'b, 'r, 'e>, ~params: 'p, ~body: 'b) => promise<result<'r, error<'e>>>
```

- **`make`:** `~fetch` defaults to the global `fetch`.
- **`baseUrl`:** keeps its path prefix, and a trailing slash is optional. An invalid `baseUrl` throws.
- **`call`:** for contracts without a body.
- **`callWithBody`:** for POST contracts.

The [architecture document](architecture.md#typed-application-errors) explains each error variant.

### `Fetch`

These are thin bindings to the Fetch API, used by the client and by handlers.

```rescript
module Request: {
  type t
  type init = {method?: string, headers?: dict<string>, body?: string}
  let make: (string, ~init: init=?) => t
}

module Response: {
  type t
  type init = {status?: int, headers?: dict<string>}
  let json: (JSON.t, ~init: init=?) => t
  let text: (string, ~init: init=?) => t
  let status: t => int
  let ok: t => bool
  let readText: t => promise<string>
  let header: (t, string) => option<string>
  let setHeader: (t, string, string) => t  // mutates; throws on immutable responses
}
```

## `@resapi/hono` (namespace `ResApiHono`)

### `Router`

```rescript
type t<'env>  // the Hono app itself
type handler<'env> = Context.t<'env> => promise<Fetch.Response.t>
type next = unit => promise<unit>
type middleware<'env> = (Context.t<'env>, next) => promise<option<Fetch.Response.t>>

let make: unit => t<'env>
let get: (t<'env>, string, handler<'env>) => t<'env>
let post: (t<'env>, string, handler<'env>) => t<'env>
let use: (t<'env>, ~path: string=?, middleware<'env>) => t<'env>
let register: (t<'env>, EndpointHandler.route<'env>) => t<'env>
let fetch: (t<'env>, Fetch.Request.t, 'env) => promise<Fetch.Response.t>
```

- **The router is a Hono app.** It's a mutable builder, so `get`, `post`, `use` and `register` add to the app and return it for piping. A router is a valid Worker default export.
- **`'env`:** the bindings type. A router that never reads `Context.env` must be annotated, as in `Router.t<unit>`.
- **`use`:** takes native Hono middleware. Hono's built-in middleware binds directly, for example `@module("hono/logger") external logger: unit => Router.middleware<'env> = "logger"`. Middleware runs in registration order, with the first `use` as the outermost layer, and it also runs for unmatched routes.
- **Exceptions:** any exception from a handler or middleware ends as Hono's plain, logged 500.
- **`fetch`:** calls the app in-process.

### `Context`

```rescript
type t<'env>

let env: t<'env> => 'env
let param: (t<'env>, string) => string
let params: t<'env> => dict<string>
let text: t<'env> => promise<string>          // request body
let header: (t<'env>, string) => option<string>  // request header
let method: t<'env> => string
let path: t<'env> => string
let res: t<'env> => Fetch.Response.t          // response so far, in middleware after next()
let setHeader: (t<'env>, string, string) => unit  // response header (Hono's c.header)
```

### `EndpointHandler`

```rescript
type input<'params, 'body> = {params: 'params, body: 'body}
type handler<'env, 'params, 'body, 'response, 'error> =
  (Context.t<'env>, input<'params, 'body>) => promise<result<'response, 'error>>
type route<'env>

let make: (Endpoint.t<'p, 'b, 'r, 'e>, handler<'env, 'p, 'b, 'r, 'e>) => route<'env>
```

The handler receives decoded `params` and `body`, and returns `Ok(response)` or `Error(declaredError)`.

| Situation | Response |
| --- | --- |
| Invalid path params (checked before the body is read) | 400 `invalid_params` |
| Body isn't valid JSON | 400 `malformed_json` |
| Body fails the codec | 400 `invalid_body` |
| `Ok(response)` | 200 with the encoded response |
| `Error(e)` | `errorStatus(e)` with `{"applicationError": ...}` |
| Exception or encoder failure | Logged, then 500 `internal` with no detail |

Framework errors have the body `{"error": {"kind", "message", "path"}}`.

## `@resapi/sury`

### `SuryCodec`

```rescript
let make: S.t<'a> => ResApi.Codec.t<'a>
```

`make` compiles the schema's decoder and encoder immediately, so call it at module top level. Workers forbid the code generation it needs once a request is running. Errors keep Sury's field path, with array indexes as strings.
