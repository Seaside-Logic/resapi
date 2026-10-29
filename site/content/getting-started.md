# Getting started

In this guide, you'll build a small accounts API and call it from a typed client. You can serve the API with [Hono](https://hono.dev) 4 on Cloudflare Workers or [Express](https://expressjs.com) 5 on Node. You'll need some familiarity with ReScript, but no experience with resAPI, Hono, or Express.

Both servers use the same contracts and client code. Where the setup differs, use the Server switch on [resapi.dev](https://resapi.dev/guides/getting-started) to choose Hono or Express. If you're reading on GitHub, you'll see both versions one after the other.

You can find complete examples in [`examples/cloudflare`](../../examples/cloudflare) for Hono on Workers and [`examples/express`](../../examples/express) for Express on Node.

## 1. Install

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

```bash
npm install @resapi/core @resapi/hono @resapi/sury hono sury sury-ppx
npm install --save-dev rescript wrangler
```

Add the following configuration to `rescript.json`:

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

The Hono adapter's modules are available under the `ResApiHono` namespace. Wrangler runs the app on Cloudflare Workers; you won't need it if you use another platform.

This guide uses Hono 4. resAPI is tested with Hono 4.13.13, both in the Workers runtime (workerd) and through direct calls to the app under Node.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

```bash
npm install @resapi/core @resapi/express @resapi/sury express sury sury-ppx
npm install --save-dev rescript
```

Add the following configuration to `rescript.json`:

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

The Express adapter's modules are available under the `ResApiExpress` namespace.

The adapter requires Express 5 and is tested with version 5.2.1. Express 4 is not supported.

</div>

resAPI requires ReScript 12.3.1 or later. The examples use `sury-ppx` to generate schema values, such as `accountSchema`, from types marked with `@schema`. You can also write Sury schemas or codecs by hand and leave out `sury-ppx`.

If npm warns that the `sury-ppx` install script isn't covered by `allowScripts`, the PPX will still work. You can clear the warning by running `npm install-scripts approve sury-ppx`.

## 2. Define a contract

Start with a contract module that defines the API's types, codecs, and endpoints. Keep server code out of this module so both the server and client can import it. The contract below defines two endpoints: one to fetch an account and one to create an account. It works with either Hono or Express.

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

A few details to keep in mind:

- **Define contracts and codecs at module top level.** `SuryCodec.make` compiles Sury's validators when you call it. Cloudflare Workers don't allow that compilation during a request.
- **Use `~params=Codec.unit` for routes without path parameters.** GET contracts don't have a request body.
- **Route parameters must match the codec.** `Endpoint.get`, `Endpoint.post`, and `Endpoint.put` check this when the contract is created. For example, using `"/accounts/:accountId"` with a `{id}` codec throws an exception and prevents the module from loading on either the server or the client.
- **Declare application errors with `withErrors`.** Each error maps to a 4xx or 5xx HTTP status. A handler can return `Error` only if its contract declares application errors.

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

- **`Router.make()` creates a Hono app.** Its type is `Router.t`, and you can export it directly as a Worker. To use Hono APIs that resAPI doesn't wrap, such as `app.onError` or `app.route`, define a ReScript external that accepts `Router.t`.
- **`Router.get`, `Router.post`, and `Router.put` add plain Hono routes.** Their handlers receive a Hono context and return a Fetch `Response`.
- **`Router.register` adds a typed endpoint.** The handler receives the Hono context and the decoded request data, such as `params` or `body`. Return `Ok(response)` for success or `Error(declaredError)` for an application error. resAPI encodes and sends the response.

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

- **`Router.make()` creates an Express app.** Its type is `Router.t`. To use Express APIs that resAPI doesn't wrap, such as `app.set`, define a ReScript external that accepts `Router.t`.
- **`Router.get`, `Router.post`, and `Router.put` add plain Express routes.** Their handlers have the signature `(req, res) => promise<unit>`.
- **`Router.register` adds a typed endpoint.** The handler receives the Express request (`Req.t`) and the decoded request data, such as `params` or `body`. Return `Ok(response)` for success or `Error(declaredError)` for an application error. resAPI encodes and sends the response.

</div>

Before calling your handler, the adapter decodes the path parameters, then parses and decodes the request body. Invalid input returns HTTP 400 with an `error` object containing `kind`, `message`, and `path`. The error kind is `invalid_params`, `malformed_json`, or `invalid_body`.

If your handler or a codec throws an exception, resAPI logs it and returns HTTP 500 without exposing the exception details. See [Errors](errors.md) for the full behavior and response formats.

## 4. Run it

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

To run the Hono app on Cloudflare Workers, add a Worker entry point and a Wrangler configuration:

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

Because the router is a Hono app, the Worker entry point only needs to export it. No additional JavaScript file or compatibility flags are required.

**Other platforms.** `@resapi/hono` depends only on Hono and uses the standard Fetch API, so the router should work on other platforms supported by Hono. You'll need to write a ReScript binding for the platform's entry point, such as `serve` from `@hono/node-server` for Node, or the appropriate adapter for AWS Lambda or Azure Functions. resAPI is tested on Workers through workerd and through direct calls to the app under Node.

### Environment bindings

The type parameter in `Router.t<'env>` describes the runtime environment. On Workers, this is the object containing your environment bindings. Define its type, then use `Context.env` to read it:

```rescript
// src/Env.res
type t = {@as("API_SECRET") apiSecret: string}
```

```rescript
let app: Router.t<Env.t> = Router.make()->Router.get("/secret-length", async ctx =>
  Fetch.Response.fromString((ctx->Context.env).apiSecret->String.length->Int.toString)
)
```

Cloudflare supplies the bindings object at runtime. As with any external binding, the type describes what you expect; it isn't checked against `wrangler.jsonc`.

You may need to add type annotations in two places:

- **A router that never reads `Context.env`** needs an explicit environment type, such as `let app: Router.t<unit> = ...`. Without it, the compiler reports "cannot be generalized".
- **A handler defined in a separate `let`** may need a context type when it reads an environment field, such as `(ctx->Context.env).db`. Use `EndpointHandler.make(async (ctx: Context.t<Env.t>, {params}) => ...)` so the compiler knows which record contains `db`. You can omit this annotation if the compiler can infer the type from another call in the handler, such as a function that accepts `Context.t<Env.t>`.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

To run the Express app on Node, add a server entry point:

```rescript
// src/Server.res
let server = App.app->ResApiExpress.Router.listen(3000, () => Console.log("Listening on :3000"))
```

```bash
npx rescript && node src/Server.res.mjs
```

Because the router is an Express app, you can use Express middleware and settings directly.

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

Use `Client.call` for contracts without a request body and `Client.callWithBody` for the POST contract above. The compiler catches incorrect parameters, missing bodies, and incorrect body types.

- **Headers:** Pass `~headers` to an individual call, or set defaults with `Client.make(~headers=...)`. Headers on a call override the client's defaults. Both can override the `content-type` set by resAPI. Header names are case-insensitive.
- **Cancellation:** Pass a Fetch `AbortSignal` as `~signal`. You can use `Fetch.AbortSignal.timeout(ms)` for a timeout, or create a controller with `Fetch.AbortController.make()` and pass its `signal`. An aborted call returns `Error(Aborted)`.

The client imports the shared contract without importing server code, so its bundle contains no Hono or Express code.

**Handle specific errors, then add a fallback.** In the example, `describe` handles a few errors explicitly and passes the rest to `Client.message`. This function provides a default English message for each error, except declared application errors, whose messages you supply through `~declared`. End your match with `Error(error) => Client.message(error, ...)` or `Error(_)` to avoid listing cases that can't occur for that endpoint. See [Errors](errors.md#on-the-client) for the full list.

Bugs in the calling code cause `Client.call` to reject its promise instead of returning `Error`. These include a missing path parameter, a codec that throws, or an invalid `baseUrl`. In each case, no request is sent.

## Next steps

- [Middleware and auth](middleware.md): use framework middleware and protect endpoints with `Reject` and typed keys
- [Request bodies](request-bodies.md): configure content types and size limits
- [Routing beside typed endpoints](routing.md): add plain routes, use other libraries, and handle unmatched requests
- [Testing](testing.md): test your server through the typed client
- [Errors](errors.md): understand server and client failures, response formats, and type errors
