# Getting started

This guide builds a small API with one typed endpoint, serves it from [Hono](https://hono.dev) 4 on Cloudflare Workers or [Express](https://expressjs.com) 5 on Node, and calls it from a typed client. It assumes you know ReScript, but not resAPI or the server framework.

Contracts and the client are the same on both servers. Sections that differ have a Hono version and an Express version: pick yours with the Server switch on [resapi.dev](https://resapi.dev/guides/getting-started). On GitHub both versions are shown, one after the other.

The complete versions are in [`examples/cloudflare`](../examples/cloudflare) (Hono on Workers) and [`examples/express`](../examples/express).

## 1. Install

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

```bash
npm install @resapi/core @resapi/hono @resapi/sury hono sury sury-ppx
npm install --save-dev rescript wrangler
```

`rescript.json`:

```json
{
  "name": "my-api",
  "sources": {"dir": "src", "subdirs": true},
  "dependencies": ["@resapi/core", "@resapi/hono", "@resapi/sury", "sury"],
  "package-specs": {"module": "esmodule", "in-source": true},
  "suffix": ".res.mjs",
  "ppx-flags": ["sury-ppx/bin"]
}
```

Modules are under the `ResApiHono` namespace. `wrangler` is only needed for Workers.

**Versions:** Hono 4 (tested on 4.13.13). resAPI is tested in workerd and by calling the app in-process under Node.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

```bash
npm install @resapi/core @resapi/express @resapi/sury express sury sury-ppx
npm install --save-dev rescript
```

`rescript.json`:

```json
{
  "name": "my-api",
  "sources": {"dir": "src", "subdirs": true},
  "dependencies": ["@resapi/core", "@resapi/express", "@resapi/sury", "sury"],
  "package-specs": {"module": "esmodule", "in-source": true},
  "suffix": ".res.mjs",
  "ppx-flags": ["sury-ppx/bin"]
}
```

Modules are under the `ResApiExpress` namespace.

**Versions:** Express 5 only (tested on 5.2.1). Express 4 is not supported.

</div>

resAPI needs ReScript 12.3.1 or later. `sury-ppx` is optional: it generates the `*Schema` values from `@schema` types. Hand-written Sury schemas, or hand-written codecs, work the same way.

npm may warn that `sury-ppx` has an install script not covered by `allowScripts`. The PPX works either way. To silence the warning, run `npm install-scripts approve sury-ppx`.

## 2. Define a contract

A contract module holds only types, codecs and contracts. It never imports server code, so clients can import it too, and it is the same for Hono and Express.

```rescript
// src/Api/AccountApi.res
open ResApi

@schema
type params = {id: string}

@schema
type account = {id: string, name: string, balance: float}

@schema
type newAccount = {name: string, balance: float}

@schema
type accountError = | @as("not_found") NotFound

let accountCodec = SuryCodec.make(accountSchema)

let getAccount =
  Endpoint.get(
    "/accounts/:id",
    ~params=SuryCodec.make(paramsSchema),
    ~response=accountCodec,
  )->Endpoint.withErrors(SuryCodec.make(accountErrorSchema), ~status=error =>
    switch error {
    | NotFound => 404
    }
  )

let createAccount = Endpoint.post(
  "/accounts",
  ~params=Codec.unit,
  ~body=SuryCodec.make(newAccountSchema),
  ~response=accountCodec,
)
```

Rules worth knowing up front:

- **Define contracts and codecs at module top level.** `SuryCodec.make` compiles Sury's validators immediately, and Cloudflare Workers forbid that compilation once a request is running.
- **`~params=Codec.unit`** is for routes without path params. GET contracts have no body.
- **Route checking:** `Endpoint.get`/`post` check that the route's `:params` match the params codec, and throw if they don't. A typo such as `"/accounts/:accountId"` with a `{id}` codec stops the module from loading, on the server and on the client.
- **Declared errors:** `withErrors` declares the endpoint's application errors and the HTTP status (4xx or 5xx) each is sent with. Endpoints without it declare none, and their handlers can't return `Error`.

## 3. Implement the server

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

```rescript
// src/App.res
open ResApi
open ResApiHono

let accounts: dict<AccountApi.account> = dict{}

let app: Router.t<unit> =
  Router.make()
  ->Router.get("/health", async _ctx => Fetch.Response.fromString("ok"))
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      switch accounts->Dict.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )
  ->Router.register(
    AccountApi.createAccount->EndpointHandler.make(async (_ctx, {body}) => {
      let account: AccountApi.account = {id: "acct_1", name: body.name, balance: body.balance}
      accounts->Dict.set(account.id, account)
      Ok(account)
    }),
  )
```

- **`Router.t` is the Hono app.** `Router.make()` is `new Hono()`, so the router is a valid Worker default export, and any Hono API resAPI doesn't wrap (`app.onError`, `app.route`, ...) binds against `Router.t` with one external.
- **`Router.get`/`post`** register plain Hono routes: the context in, a Fetch `Response` out.
- **`Router.register`** adds a typed endpoint. The handler gets the Hono context and the decoded `params` and `body`. It returns `Ok(response)` or `Error(declaredError)`, and resAPI sends the response.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

```rescript
// src/App.res
open ResApiExpress

let accounts: dict<AccountApi.account> = dict{}

let app =
  Router.make()
  ->Router.get("/health", async (_req, res) => res->Res.send("ok"))
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_req, {params}) =>
      switch accounts->Dict.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )
  ->Router.register(
    AccountApi.createAccount->EndpointHandler.make(async (_req, {body}) => {
      let account: AccountApi.account = {id: "acct_1", name: body.name, balance: body.balance}
      accounts->Dict.set(account.id, account)
      Ok(account)
    }),
  )
```

- **`Router.t` is the Express app.** Any Express API not wrapped here, such as `app.set`, binds against it with one external.
- **`Router.get`/`post`** register plain Express routes: `(req, res) => promise<unit>`.
- **`Router.register`** adds a typed endpoint. The handler gets the Express `Req.t` and the decoded `params` and `body`. It returns `Ok(response)` or `Error(declaredError)`, and resAPI sends the response.

</div>

Before your handler runs, the adapter decodes path params, then parses and decodes the body. Invalid input gets a 400 with `{"error": {"kind", "message", "path"}}`. The kinds are `invalid_params`, `malformed_json` and `invalid_body`. An exception from your handler or a codec gets a 500 that reveals no detail, and the exception is logged. [Errors](errors.md) covers every case.

## 4. Run it

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

On Cloudflare Workers:

```rescript
// src/Worker.res
let default = App.app
```

```jsonc
// wrangler.jsonc
{
  "name": "my-api",
  "main": "src/Worker.res.mjs",
  "compatibility_date": "2026-10-01"
}
```

```bash
npx rescript && npx wrangler dev
```

A router is a Hono app, so `let default = App.app` is the whole Worker entry. No JavaScript file or compatibility flags are needed.

**Other platforms.** `@resapi/hono` imports only Hono and uses the standard Fetch API, so the router should also work on other platforms Hono supports. Each platform needs its own entry point, though, such as `@hono/node-server`'s `serve` on Node or an adapter for AWS Lambda or Azure Functions, and you write that binding yourself. resAPI is tested only on Workers (in workerd) and by calling the app in-process under Node.

### Environment bindings

`Router.t<'env>` carries the type of the runtime environment: on Workers, the bindings object. Read it with `Context.env`:

```rescript
// src/Env.res
type t = {@as("API_SECRET") apiSecret: string}
```

```rescript
let app: Router.t<Env.t> = Router.make()->Router.get("/secret-length", async ctx =>
  Fetch.Response.fromString((ctx->Context.env).apiSecret->String.length->Int.toString)
)
```

The type is a declaration, like any external binding. Cloudflare supplies the object, and nothing checks it against `wrangler.jsonc`.

Two annotations come up in practice:

- **A router that never reads `Context.env`** needs one, as in `let app: Router.t<unit> = ...`. Otherwise the compiler reports "cannot be generalized".
- **A handler defined in its own `let`** that reads a field of the env, such as `(ctx->Context.env).db`, needs its context annotated: `EndpointHandler.make(async (ctx: Context.t<Env.t>, {params}) => ...)`. Without it, nothing tells the compiler which record `db` belongs to. A handler that also calls a function taking `Context.t<Env.t>` gets the type from that call.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

On Node:

```rescript
// src/Server.res
let server = App.app->ResApiExpress.Router.listen(3000, () => Console.log("Listening on :3000"))
```

```bash
npx rescript && node src/Server.res.mjs
```

A router is an Express app, so Express middleware and settings work on it as is.

</div>

## 5. Call it from a client

```rescript
// src/AccountClient.res
open ResApi

let client = Client.make(~baseUrl="https://my-api.example.com")

let describe = async id =>
  switch await client->Client.call(AccountApi.getAccount, ~params={id: id}) {
  | Ok(account) => account.name
  | Error(Application({error: NotFound})) => "not found"
  | Error(Unauthorized(_)) => "please sign in"
  | Error(Network(message)) => `network error: ${message}`
  | Error(error) => Client.message(error, ~declared=_ => "request failed")
  }

let create = (newAccount: AccountApi.newAccount, ~token) =>
  client->Client.callWithBody(
    AccountApi.createAccount,
    ~params=(),
    ~body=newAccount,
    ~headers=dict{"authorization": `Bearer ${token}`},
  )

// Gives up after 5 seconds with Error(Aborted).
let describeQuickly = id =>
  client->Client.call(AccountApi.getAccount, ~params={id: id}, ~signal=Fetch.AbortSignal.timeout(5000))
```

Use `Client.call` for contracts without a body and `Client.callWithBody` for POST. Passing the wrong params, a missing body or the wrong body type is a compile error.

- **Headers:** `~headers` on a call, or `Client.make(~headers=...)` for every call. A per-call header overrides the client's, and both override resAPI's `content-type`. Names are case-insensitive.
- **Cancellation:** `~signal` takes a Fetch `AbortSignal`, such as `Fetch.AbortSignal.timeout(ms)` or `controller.signal` from a `Fetch.AbortController.make()`. An aborted call returns `Error(Aborted)`.

The client module imports only the contract, so a bundle built from it contains no Hono or Express code.

**Match the cases you handle, then fall back.** `Client.message(error, ~declared)` gives an English default for every case except the contract's declared errors, which you word yourself. A match that ends with `Error(error) => Client.message(error, ...)` (or `Error(_)`) doesn't have to list cases that can't happen for a given endpoint. The full list is in [Errors](errors.md#on-the-client).

`Client.call` rejects (throws) for bugs in the calling code: a missing path param, a codec that throws, or an invalid `baseUrl`. Nothing is sent in those cases.

## Next steps

- [Middleware and auth](middleware.md): framework middleware, and protecting endpoints with `Reject` and typed keys
- [Request bodies](request-bodies.md): content types and size limits
- [Routing beside typed endpoints](routing.md): plain routes, other libraries, not-found handlers
- [Testing](testing.md): calling the server from the typed client in tests
- [Errors](errors.md): every failure the server and client report, the wire formats, and reading type errors
