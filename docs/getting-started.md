# Getting started

This guide builds a small API with one typed endpoint, serves it from a Cloudflare Worker, and calls it from a typed client. It assumes you know ReScript, but not resAPI or Hono.

The complete version is in [`examples/cloudflare`](../examples/cloudflare). The [Hono guide](hono.md) collects the adapter's details for reference, and the [Express guide](express.md) covers Express.

## 1. Install

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

resAPI needs ReScript 12.3.1 or later. `sury-ppx` is optional: it generates the `*Schema` values from `@schema` types. Hand-written Sury schemas, or hand-written codecs, work the same way.

npm may warn that `sury-ppx` has an install script not covered by `allowScripts`. The PPX works either way. To silence the warning, run `npm install-scripts approve sury-ppx`.

## 2. Define a contract

A contract module holds only types, codecs and contracts. It never imports server code, so clients can import it too.

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

`Router.get`/`post` register plain routes: you get the context and return a Fetch `Response`. `Router.register` adds a typed endpoint. Its handler receives decoded `params` and `body`, and returns `Ok(response)` or `Error(declaredError)`.

Before your handler runs, the adapter decodes path params, then parses and decodes the body. Invalid input gets a 400 with `{"error": {"kind", "message", "path"}}`. The kinds are `invalid_params`, `malformed_json` and `invalid_body`. An exception from your handler or a codec gets a 500 that reveals no detail, and the exception is logged. [Errors](errors.md) covers every case.

## 4. Run it as a Worker

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

A router is a Hono app, so it is already a valid Worker module. No JavaScript entry file or compatibility flags are needed.

### Environment bindings

Give the router your bindings type and read it with `Context.env`:

```rescript
// src/Env.res
type t = {@as("API_SECRET") apiSecret: string}
```

In a handler on a `Router.t<Env.t>`:

```rescript
let secret = (ctx->Context.env).apiSecret
```

The type is a declaration, like any external binding. Cloudflare supplies the object and nothing checks it against `wrangler.jsonc`.

If a router never reads `Context.env`, annotate it, as in `let app: Router.t<unit> = ...`. Otherwise the compiler reports "cannot be generalized".

### Middleware

`Router.use` takes native Hono middleware, so Hono's built-ins bind with one external:

```rescript
@module("hono/logger") external logger: unit => Router.middleware<'env> = "logger"

let app: Router.t<unit> = Router.make()->Router.use(logger())
```

Your own middleware has the same shape. Call `await next()` and return `None`, or return `Some(response)` to answer early:

```rescript
let poweredBy: Router.middleware<'env> = async (ctx, next) => {
  await next()
  ctx->Context.setHeader("x-powered-by", "resAPI")
  None
}
```

## 5. Call it from a client

```rescript
// src/AccountClient.res
open ResApi

let client = Client.make(~baseUrl="https://my-api.example.workers.dev")

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

The client module imports only the contract, so a bundle built from it contains no Hono code.

**Match the cases you handle, then fall back.** `Client.message(error, ~declared)` gives an English default for every case except the contract's declared errors, which you word yourself. A match that ends with `Error(error) => Client.message(error, ...)` (or `Error(_)`) doesn't have to list cases that can't happen for a given endpoint. The full list is in [Errors](errors.md#on-the-client).

`Client.call` rejects (throws) for bugs in the calling code: a missing path param, a codec that throws, or an invalid `baseUrl`. Nothing is sent in those cases.

## 6. Protect endpoints with middleware

Auth is ordinary Hono middleware, mounted for a path. It runs before resAPI decodes anything, and contracts don't mention it. resAPI adds two small helpers: `Reject` answers in a shape the typed client understands, and a typed key passes the signed-in user to handlers.

```rescript
// src/Api/ProfileApi.res
open ResApi

type profile = {name: string}

let profileCodec = Codec.object(
  ~decode=fields => {name: fields->Codec.field("name", Codec.string)},
  ~encode=({name}) => [("name", Codec.string.encode(name))],
)

let getProfile = Endpoint.get("/me", ~params=Codec.unit, ~response=profileCodec)
```

```rescript
// src/BearerAuth.res
open ResApiHono

type user = {name: string}

// The type is declared here; middleware stores the value, handlers read it back.
let userKey: ResApi.Key.t<user> = ResApi.Key.make("user")

let requireToken: Router.middleware<'env> = async (ctx, next) =>
  switch ctx->Context.header("authorization") {
  | None => Some(Reject.unauthenticated())
  | Some("Bearer secret-token") =>
    ctx->Context.set(userKey, {name: "Ada"})
    await next()
    None
  | Some(_) => Some(Reject.unauthenticated(~reason="invalid_token"))
  }
```

```rescript
// src/ProfileServer.res
open ResApiHono

let app: Router.t<unit> =
  Router.make()
  ->Router.use(~path="/me", BearerAuth.requireToken)
  ->Router.register(
    ProfileApi.getProfile->EndpointHandler.make(async (ctx, _) =>
      Ok({ProfileApi.name: (ctx->Context.getOrThrow(BearerAuth.userKey)).name})
    ),
  )
```

- **Register middleware before the routes it protects.** Hono runs handlers in registration order.
- **`Reject`** answers `401 {"error": {"kind": "unauthenticated", "message": "invalid_token", "path": []}}` (or `forbidden` with 403). The client sees `Error(Unauthorized({status, reason}))`, here with `reason: Some("invalid_token")`. Any other middleware's 401 or 403, such as `hono/bearer-auth`'s, is `Unauthorized` too, with `reason: None`.
- **Keys** use Hono's own `c.set`/`c.get` names, so they also read values that third-party middleware sets (for example `Key.make("jwtPayload")` for `hono/jwt`). `getOrThrow` is for routes behind the middleware. A missing value means it isn't mounted for that path, which becomes a logged 500.

## 7. Test without a server

`Client.make` takes a `~fetch` function. Pass the router's own fetch to run the client against the server in-process:

```rescript
let client = Client.make(~baseUrl="http://localhost", ~fetch=request => App.app->Router.fetch(request, ()))
```

Under Node, this exercises routing, validation and codecs. It doesn't enforce Workers restrictions. For that, run the tests against `wrangler dev` as well (see `scripts/test-worker.sh`).

## Reading type errors

resAPI's checks are type errors, and ReScript prints the full types involved, so some messages are long. Look for the pair "This has type … But it's expected to have type …": it names what you wrote and what the contract requires. With long generic types, the final "The incompatible parts" lines name just the difference. For example, a handler for `getAccount` that returns `Ok("a1")` reports:

```text
This has type: string
But it's expected to have type: AccountApi.account
```
