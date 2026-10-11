# API reference

This page lists the public API, which each package's `.resi` files enforce.

## `@resapi/core` (namespace `ResApi`)

### `Codec`

```rescript
type error = {path: array<string>, message: string}
type t<'a> = {decode: JSON.t => result<'a, error>, encode: 'a => JSON.t}

let unit: t<unit>  // decodes anything to (), encodes to {}
let string: t<string>
let int: t<int>          // rejects non-integers and values outside 32 bits
let float: t<float>
let bool: t<bool>
let enum: (~values: array<'a>, ~toString: 'a => string, ~name: string=?) => t<'a>
let array: t<'a> => t<array<'a>>
let option: t<'a> => t<option<'a>>
let refine: (t<'a>, 'a => result<'b, string>, 'b => 'a) => t<'b>

type fields
let field: (fields, string, t<'a>) => 'a
let object: (~decode: fields => 'a, ~encode: 'a => array<(string, JSON.t)>) => t<'a>
```

- **`object`:** decode by building the record literal from `field`s, so a field left out is a compile error. Encode by listing every field.
- **Missing fields:** a missing field decodes as `null`. An `option` field becomes `None`, and any other fails with "Missing field". `None` encodes as `null`.
- **`enum`:** with `@as` variants, `~toString=v => (v :> string)` keeps the wire names in the type, and the compiler checks the coercion. List every value in `~values`.
- **Messages:** the built-in messages are generic ("Expected boolean"). Use `refine` for your own.
- **Where to refine:** refine a field's codec, not a whole record's, so errors keep the field's path.
- Any `Codec.t` works, including a hand-written one or `SuryCodec.make(...)`.

Use `Codec.unit` as `~params` for routes without path params. A codec's `path` names the field that failed, as in `["owner", "name"]` or `["tags", "1"]`.

### `Endpoint`

```rescript
type method = Get | Post
type noError  // no values: the error type of endpoints that declare none

type t<'params, 'body, 'response, 'error> = private {  // readable, but built only by get/post
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

type any = private {method: method, path: string}  // a contract with its types erased
let any: t<'p, 'b, 'r, 'e> => any
```

- **Route checking:** `get` and `post` throw if the route's `:params` don't match the params codec (see `RouteCheck`). Define contracts at module top level, so a mismatch fails at load.
- **`withErrors`:** declares the endpoint's application errors. `~status` must return 400–599.
- **`any`:** erases a contract's types so different contracts fit in one list. Keep one list of every contract and call the adapter's `Router.assertRegistered(router, list)` in a test, so a forgotten `register` fails the test instead of answering 404.

### `RouteCheck`

```rescript
type outcome = Valid | Invalid(string) | CannotValidate(string)

let check: (string, Codec.t<'p>) => outcome
let assertValid: (string, Codec.t<'p>) => unit  // throws on Invalid
```

`Endpoint.get` and `post` call `assertValid`. `check` is public so tests can assert on the outcome. A `CannotValidate` result means a codec rejected the probe value at a real route param, for example because it refines strings. See the [architecture document](architecture.md#route-checking-at-construction) for the probe and its limits.

### `Key`

```rescript
type t<'a>
let make: string => t<'a>   // annotate: let userKey: Key.t<User.t> = Key.make("user")
let name: t<'a> => string
```

A typed name for a value middleware stores on a request (`Context.set` on Hono, `Req.set` on Express) and handlers read back. The name is the framework's own, so keys also read values third-party middleware sets. The type is a declaration, not a proof. On Express the name is a property on `req`, so it mustn't be one of Express's own (see [the Express guide](express.md#middleware)).

### `Client`

```rescript
type t
type error<'e> =
  | Application({status: int, error: 'e})
  | Unauthorized({status: int, reason: option<string>})
  | Network(string)
  | Aborted
  | UnexpectedStatus({status: int, body: string})
  | InvalidResponse(Codec.error)

let make: (
  ~baseUrl: string,
  ~fetch: Fetch.Request.t => promise<Fetch.Response.t>=?,  // default: Fetch.fetchWithRequest
  ~headers: dict<string>=?,  // sent with every call
) => t

let call: (
  t, Endpoint.t<'p, unit, 'r, 'e>, ~params: 'p,
  ~headers: dict<string>=?, ~signal: Fetch.AbortSignal.t=?,
) => promise<result<'r, error<'e>>>
let callWithBody: (
  t, Endpoint.t<'p, 'b, 'r, 'e>, ~params: 'p, ~body: 'b,
  ~headers: dict<string>=?, ~signal: Fetch.AbortSignal.t=?,
) => promise<result<'r, error<'e>>>

let message: (error<'e>, ~declared: 'e => string) => string
```

- **`make`:** `~fetch` defaults to the global `fetch`.
- **Headers:** per-call `~headers` override the client's, and both override resAPI's `content-type`. Names are case-insensitive.
- **`~signal`:** a Fetch `AbortSignal`. Aborting it, or its timeout firing, returns `Error(Aborted)`.
- **`baseUrl`:** keeps its path prefix, and a trailing slash is optional. An invalid `baseUrl` throws.
- **`call`:** for contracts without a body. **`callWithBody`:** for POST contracts.
- **Throws:** both reject the promise for bugs in the calling code: a missing or non-scalar path param, a codec that throws, an invalid `baseUrl`.
- **`Unauthorized`:** any 401/403 that isn't a declared error. `reason` comes from a resAPI `Reject`.
- **`message`:** English defaults for every case except declared errors.

[Errors](errors.md#on-the-client) explains each error variant.

### `Fetch`

A source-compatible subset of [`@rescript/webapi`](https://github.com/rescript-lang/experimental-rescript-webapi)'s Fetch bindings: the same module names, functions, labels and record fields, only fewer of them. When ReScript 13 and webapi are stable, `ResApi.Fetch` will become re-exports of webapi, and code written against it keeps compiling. Bind other libraries' Fetch functions against these types.

```rescript
module Request: {
  type t = private {method: string, url: string, headers: Headers.t, signal: AbortSignal.t, bodyUsed: bool}
  type requestInit = {method?: string, headers?: HeadersInit.t, body?: Nullable.t<BodyInit.t>, signal?: Nullable.t<AbortSignal.t>}
  let fromURL: (string, ~init: requestInit=?) => t
  let json: t => promise<JSON.t>
  let text: t => promise<string>
  let clone: t => t
}

module Response: {
  type t = private {status: int, ok: bool, statusText: string, url: string, redirected: bool, headers: Headers.t, bodyUsed: bool}
  type responseInit = {status?: int, statusText?: string, headers?: HeadersInit.t}
  let fromString: (string, ~init: responseInit=?) => t
  let fromNull: (~init: responseInit=?) => t
  let jsonR: (~data: JSON.t, ~init: responseInit=?) => t   // Response.json(data, init)
  let json: t => promise<JSON.t>                            // reads the body
  let text: t => promise<string>                            // reads the body
  let clone: t => t
}

module Headers: {
  type t
  let make: unit => t
  let fromDict: dict<string> => t
  let get: (t, string) => Null.t<string>
  let has: (t, string) => bool
  let set: (t, ~name: string, ~value: string) => unit
  let append: (t, ~name: string, ~value: string) => unit
  let delete: (t, string) => unit
}

module HeadersInit: { type t; let fromDict: dict<string> => t; let fromHeaders: Headers.t => t; let fromKeyValueArray: array<(string, string)> => t }
module BodyInit: { type t; let fromString: string => t }

module AbortSignal: { type t; let timeout: int => t; let abort: (~reason: JSON.t=?) => t; let any: array<t> => t }
module AbortController: { type t = private {signal: AbortSignal.t}; let make: unit => t; let abort: (t, ~reason: JSON.t=?) => unit }

let fetch: (string, ~init: Request.requestInit=?) => promise<Response.t>
let fetchWithRequest: (Request.t, ~init: Request.requestInit=?) => promise<Response.t>
```

For example, `Fetch.Response.jsonR(~data=json, ~init={status: 201})`, `response.status`, or `response.headers->Fetch.Headers.set(~name="x-powered-by", ~value="resAPI")`.

### `Dispatch` (unstable)

```rescript
type input<'params, 'body> = {params: 'params, body: 'body}
type response = {status: int, body: JSON.t}
type rawBody = Text(promise<string>) | Parsed(JSON.t)

let errorResponse: (~status: int, ~kind: string, ~message: string, ~path: array<string>=?) => response
let run: (
  Endpoint.t<'p, 'b, 'r, 'e>,
  ~params: dict<string>,
  ~readBody: unit => rawBody,
  ~handle: input<'p, 'b> => promise<result<'r, 'e>>,
) => promise<response>
```

The server pipeline shared by `@resapi/hono` and `@resapi/express`. It is public only because the adapters need it, and it may change in any release. Applications don't call it.

## `@resapi/hono` (namespace `ResApiHono`)

Hono 4. See the [Hono guide](hono.md).

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
let all: (t<'env>, string, handler<'env>) => t<'env>       // every HTTP method
let notFound: (t<'env>, handler<'env>) => t<'env>         // unmatched requests
let assertRegistered: (t<'env>, array<Endpoint.any>) => unit  // for tests
let fetch: (t<'env>, Fetch.Request.t, 'env) => promise<Fetch.Response.t>
```

- **The router is a Hono app.** It's a mutable builder, so `get`, `post`, `use` and `register` add to the app and return it for piping. A router is a valid Worker default export.
- **`'env`:** the bindings type. A router that never reads `Context.env` must be annotated, as in `Router.t<unit>`.
- **`use`:** takes native Hono middleware. Hono's built-in middleware binds directly, for example `@module("hono/logger") external logger: unit => Router.middleware<'env> = "logger"`. Middleware runs in registration order, with the first `use` as the outermost layer, and it also runs for unmatched routes.
- **Exceptions:** an exception from a plain handler or middleware ends as Hono's plain, logged 500.
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
let request: t<'env> => Fetch.Request.t          // the original request (c.req.raw)
let set: (t<'env>, Key.t<'a>, 'a) => unit
let get: (t<'env>, Key.t<'a>) => option<'a>   // None when unset, undefined or null
let getOrThrow: (t<'env>, Key.t<'a>) => 'a     // for routes behind the middleware
```

### `EndpointHandler`

```rescript
type input<'params, 'body> = {params: 'params, body: 'body}
type handler<'env, 'params, 'body, 'response, 'error> =
  (Context.t<'env>, input<'params, 'body>) => promise<result<'response, 'error>>
type route<'env>

let make: (Endpoint.t<'p, 'b, 'r, 'e>, handler<'env, 'p, 'b, 'r, 'e>) => route<'env>
```

The handler receives decoded `params` and `body`, and returns `Ok(response)` (sent as 200) or `Error(declaredError)`. Invalid input is a 400, and an exception is logged and answered with a 500 that reveals nothing. It never reaches Hono's `onError`. [Errors](errors.md#on-the-server) lists every case and the wire formats.

### `Reject`

```rescript
let unauthenticated: (~reason: string=?) => Fetch.Response.t  // 401
let forbidden: (~reason: string=?) => Fetch.Response.t        // 403
```

For middleware: `Some(Reject.forbidden(~reason="mfa_required"))`. The body is `{"error": {"kind": "unauthenticated" | "forbidden", "message": <reason or "">, "path": []}}`.

## `@resapi/express` (namespace `ResApiExpress`)

Express 5 only. See the [Express guide](express.md).

### `Router`

```rescript
type t                                   // the Express app
type handler = (Req.t, Res.t) => promise<unit>
type next = unit => unit
type middleware = (Req.t, Res.t, next) => unit
type server

let make: unit => t
let get: (t, string, handler) => t
let post: (t, string, handler) => t
let use: (t, ~path: string=?, middleware) => t
let register: (t, EndpointHandler.route) => t
let all: (t, string, handler) => t                // every HTTP method
let assertRegistered: (t, array<Endpoint.any>) => unit  // for tests
let listen: (t, int, unit => unit) => server  // port 0 picks a free port
let close: server => unit
```

- **`use`:** takes native Express middleware, such as `@module("express") external json: unit => Router.middleware = "json"`. The first `use` is the outermost layer, and middleware also runs for unmatched routes.
- **`register`:** mounts a typed endpoint. POST routes get a raw-text body parser (100kb limit), and a body already parsed upstream is used as is.
- **Exceptions:** a rejected plain handler or a thrown middleware exception goes to Express's error handler, with ReScript exceptions rethrown as JS `Error`s.

### `Req` and `Res`

```rescript
// Req: Express's request
type t
let params: t => dict<string>            // percent-decoded
let body: t => Nullable.t<JSON.t>        // set by body-parsing middleware
let header: (t, string) => option<string>
let method: t => string
let path: t => string
let set: (t, Key.t<'a>, 'a) => unit
let get: (t, Key.t<'a>) => option<'a>   // None when unset, undefined or null
let getOrThrow: (t, Key.t<'a>) => 'a     // for routes behind the middleware

// Res: Express's response
type t
let status: (t, int) => t
let json: (t, JSON.t) => unit
let send: (t, string) => unit
let setHeader: (t, string, string) => t
```

### `EndpointHandler`

```rescript
type input<'params, 'body> = {params: 'params, body: 'body}
type handler<'params, 'body, 'response, 'error> =
  (Req.t, input<'params, 'body>) => promise<result<'response, 'error>>
type route

let make: (Endpoint.t<'p, 'b, 'r, 'e>, handler<'p, 'b, 'r, 'e>) => route
```

Behaves as on Hono. Typed-endpoint exceptions never reach Express's error middleware.

### `Reject`

```rescript
let unauthenticated: (Res.t, ~reason: string=?) => unit  // 401
let forbidden: (Res.t, ~reason: string=?) => unit        // 403
```

Sends the response; call it instead of `next()`. The body is the same as on Hono.

## `@resapi/sury`

### `SuryCodec`

```rescript
let make: S.t<'a> => ResApi.Codec.t<'a>
```

`make` compiles the schema's decoder and encoder immediately, so call it at module top level. Workers forbid the code generation it needs once a request is running. Errors keep Sury's field path, with array indexes as strings.
