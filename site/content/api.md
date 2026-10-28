# API reference

This page describes the public API defined by each package's `.resi` interface files.

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

- **`object`:** build a record literal with `field` calls in the decoder. The compiler catches missing record fields. In the encoder, list each field and its encoded value.
- **Missing fields:** a missing field is passed to its codec as `null`. An `option` field decodes to `None`; other fields fail with "Missing field". `None` encodes as `null`.
- **`enum`:** for `@as` variants, use `~toString=v => (v :> string)` to reuse the JSON names defined in the type. The compiler checks the coercion. Include every value in `~values`.
- **Messages:** built-in codecs return generic messages, such as "Expected boolean". Use `refine` to provide a custom message.
- **Where to refine:** apply `refine` to individual field codecs to preserve the field path in errors.
- Contracts accept any `Codec.t`, whether written by hand or created with `SuryCodec.make(...)`.

Use `Codec.unit` as `~params` for routes without path parameters. In a decode error, `path` identifies the field that failed, for example `["owner", "name"]` or `["tags", "1"]`.

### `Endpoint`

```rescript
type method = Get | Post | Put
type noError  // no values: the error type of endpoints that declare none

type t<'params, 'body, 'response, 'error> = private {  // readable, but built only by get/post/put
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
let put: (string, ~params: Codec.t<'p>, ~body: Codec.t<'b>, ~response: Codec.t<'r>) => t<'p, 'b, 'r, noError>
let withErrors: (t<'p, 'b, 'r, noError>, Codec.t<'e>, ~status: 'e => int) => t<'p, 'b, 'r, 'e>

type any = private {method: method, path: string}  // a contract with its types erased
let any: t<'p, 'b, 'r, 'e> => any
```

- **Route checking:** `get`, `post`, and `put` check that the route parameter names match the parameter codec and throw if they detect a mismatch. See `RouteCheck` for details and limitations. Define contracts at module top level so a mismatch prevents the module from loading.
- **`withErrors`:** declares the endpoint's application error type and maps each error to a status. `~status` must return a value from 400 to 599.
- **`any`:** erases the contract's type parameters so contracts with different types can share a list. Pass a list of all your contracts to the adapter's `Router.assertRegistered(router, list)` in a test to catch missing registrations before they cause unexpected 404 responses.

### `RouteCheck`

```rescript
type outcome = Valid | Invalid(string) | CannotValidate(string)

let check: (string, Codec.t<'p>) => outcome
let assertValid: (string, Codec.t<'p>) => unit  // throws on Invalid
```

`Endpoint.get`, `Endpoint.post`, and `Endpoint.put` call `assertValid` when creating a contract. Tests can call `check` to inspect the result directly. `CannotValidate` means the codec rejected the sample value for an existing route parameter, for example because it requires a specific string format. The [architecture document](architecture.md#route-checking-at-construction) explains how this check works and its limitations.

### `Key`

```rescript
type t<'a>
let make: string => t<'a>   // annotate: let userKey: Key.t<User.t> = Key.make("user")
let name: t<'a> => string
let orThrow: (option<'a>, t<'a>) => 'a  // backs the adapters' getOrThrow
```

A key gives a stored request value a name and type. Middleware writes the value with `Context.set` on Hono or `Req.set` on Express, and handlers read it using the same key. Keys use the framework's native storage, so they can also read values set by third-party middleware. The type is a declaration and isn't checked at runtime. On Express, the key name is a property on `req` and must not conflict with Express's own fields. See [Middleware and auth](middleware.md).

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

- **`make`:** creates a client. If you omit `~fetch`, it uses the global `fetch` function.
- **Headers:** for JSON requests, headers merge in this order: client defaults, resAPI's `content-type`, then headers supplied to the call. Later values override earlier ones. Header names are case-insensitive.
- **`~signal`:** accepts a Fetch `AbortSignal`. If the signal is aborted or times out, the call returns `Error(Aborted)`.
- **`baseUrl`:** the client preserves its path prefix. A trailing slash is optional. An invalid URL causes the call to throw.
- **`call` and `callWithBody`:** use `call` for contracts without a request body and `callWithBody` for POST and PUT contracts.
- **Exceptions:** both functions reject their promise for bugs in the calling code, such as a missing or non-scalar path parameter, a codec that throws, or an invalid `baseUrl`.
- **`Unauthorized`:** reports a 401 or 403 that is not a declared application error. The optional `reason` comes from a resAPI `Reject` response.
- **`message`:** provides a default English message for each error. Supply `~declared` to choose messages for declared application errors.

[Errors](errors.md#on-the-client) explains each error variant.

### `Fetch`

`ResApi.Fetch` provides a subset of [`@rescript/webapi`](https://github.com/rescript-lang/experimental-rescript-webapi)'s Fetch bindings, using the same module names, functions, labels, and record fields. The plan is to re-export webapi's bindings when ReScript 13 and webapi are stable, preserving compatibility with existing code. Use these types when writing bindings for other libraries' Fetch functions.

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

For example, use `Fetch.Response.jsonR(~data=json, ~init={status: 201})` to create a JSON response, `response.status` to read its status, or `response.headers->Fetch.Headers.set(~name="x-powered-by", ~value="resAPI")` to set a header.

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

The shared request pipeline used by `@resapi/hono` and `@resapi/express`. This module is public so the adapters can access it, but its interface is unstable and may change between releases. Application code should use the adapters instead.

## `@resapi/hono` (namespace `ResApiHono`)

The Hono adapter supports Hono 4. Choose Hono in [Getting started](getting-started.md) and the other guides for examples.

### `Router`

```rescript
type t<'env>  // the Hono app itself
type handler<'env> = Context.t<'env> => promise<Fetch.Response.t>
type next = unit => promise<unit>
type middleware<'env> = (Context.t<'env>, next) => promise<option<Fetch.Response.t>>

let make: unit => t<'env>
let get: (t<'env>, string, handler<'env>) => t<'env>
let post: (t<'env>, string, handler<'env>) => t<'env>
let put: (t<'env>, string, handler<'env>) => t<'env>
let use: (t<'env>, ~path: string=?, middleware<'env>) => t<'env>
let register: (t<'env>, EndpointHandler.route<'env>) => t<'env>
let all: (t<'env>, string, handler<'env>) => t<'env>       // every HTTP method
let notFound: (t<'env>, handler<'env>) => t<'env>         // unmatched requests
let assertRegistered: (t<'env>, array<Endpoint.any>) => unit  // for tests
let fetch: (t<'env>, Fetch.Request.t, 'env) => promise<Fetch.Response.t>
```

- **The router is a Hono app.** `get`, `post`, `put`, `use`, and `register` modify the app and return it, so you can pipe calls together. You can export the router directly as a Worker.
- **`'env`:** describes the environment bindings. If the router never reads `Context.env`, add an explicit type annotation, such as `Router.t<unit>`.
- **`use`:** accepts native Hono middleware. For example, bind the logger with `@module("hono/logger") external logger: unit => Router.middleware<'env> = "logger"`. Middleware runs in registration order, with the first `use` forming the outermost layer. It also runs for unmatched requests within its path scope.
- **Exceptions:** plain handlers and middleware use Hono's error handling. By default, unhandled errors are logged and returned as HTTP 500.
- **`fetch`:** sends a request directly to the app in the same process, without an HTTP server.

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

The handler receives decoded `params` and `body`. Return `Ok(response)` for an HTTP 200 response or `Error(declaredError)` for a declared application error. Invalid input returns HTTP 400. Exceptions are logged and returned as HTTP 500 without exposing their details; they do not reach Hono's `onError`. See [Errors](errors.md#on-the-server) for all cases and response formats.

### `Reject`

```rescript
let unauthenticated: (~reason: string=?) => Fetch.Response.t  // 401
let forbidden: (~reason: string=?) => Fetch.Response.t        // 403
```

Use these responses in middleware, for example `Some(Reject.forbidden(~reason="mfa_required"))`. The body has the format `{"error": {"kind": "unauthenticated" | "forbidden", "message": <reason or "">, "path": []}}`.

## `@resapi/express` (namespace `ResApiExpress`)

The Express adapter requires Express 5. Choose Express in [Getting started](getting-started.md) and the other guides for examples.

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
let put: (t, string, handler) => t
let use: (t, ~path: string=?, middleware) => t
let register: (t, EndpointHandler.route) => t
let all: (t, string, handler) => t                // every HTTP method
let assertRegistered: (t, array<Endpoint.any>) => unit  // for tests
let listen: (t, int, unit => unit) => server  // port 0 picks a free port
let close: server => unit
```

- **`use`:** accepts native Express middleware. For example, bind the JSON parser with `@module("express") external json: unit => Router.middleware = "json"`. Middleware runs in registration order, including for unmatched requests within its path scope.
- **`register`:** adds a typed endpoint. POST and PUT routes include a raw-text body parser with a 100kb limit. If earlier middleware has already parsed the body, resAPI uses that result.
- **Exceptions:** rejected promises from plain handlers and exceptions from middleware go to Express's error handler. Raw ReScript exceptions are converted to JavaScript `Error` objects.

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

As on Hono, the handler receives decoded request data and returns `Ok(response)` or `Error(declaredError)`. resAPI handles typed endpoint exceptions itself, so they never reach Express's error middleware.

### `Reject`

```rescript
let unauthenticated: (Res.t, ~reason: string=?) => unit  // 401
let forbidden: (Res.t, ~reason: string=?) => unit        // 403
```

These functions send the rejection response. Call them instead of `next()` to stop processing the request. The response body has the same format as on Hono.

## `@resapi/sury`

### `SuryCodec`

```rescript
let make: S.t<'a> => ResApi.Codec.t<'a>
```

`make` compiles the schema's decoder and encoder when you call it. Define codecs at module top level because Workers prohibit this code generation during a request. Decode errors preserve Sury's field path, with array indexes represented as strings.
