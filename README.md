# resAPI

_Type-safe HTTP contracts for ReScript._

Define an HTTP endpoint once as a contract: method, path, and codecs for params, body, response and declared errors. Servers and clients both import that contract. The compiler checks handlers and calls against it, and the codecs validate every request and response at runtime.

resAPI works with [Hono](https://hono.dev) (including Cloudflare Workers) and [Express](https://expressjs.com) 5 on the server, any Fetch environment on the client, and [Sury](https://github.com/DZakh/sury) schemas or hand-written codecs.

- **Website:** https://resapi.dev
- **Get started:** [docs/getting-started.md](docs/getting-started.md) (Hono on Workers) or [docs/express.md](docs/express.md)

> **Status: 0.1.0 preview.** The API may change in 0.x releases. See the [changelog](CHANGELOG.md) for what is supported and the known limitations.

## Why

- **One definition, both sides.** The server handler and the client call get their types from the same contract value, with no generated code.
- **Runtime validation at both boundaries.** The server decodes params and bodies before your handler runs. The client decodes responses before you see them, with no casts.
- **Compile-time checking.** Wrong param fields, wrong body types, wrong handler results and undeclared errors are compile errors.
- **Typed application errors.** An endpoint declares its expected failures (`NotFound`, `AccessDenied`) and their HTTP statuses. They stay separate from network, validation and server errors.
- **Runtime independence.** Contracts and the client depend only on Fetch. Server adapters exist for Hono (runs on Cloudflare Workers with no JS glue) and Express (Node).

## Example

```bash
npm install @resapi/core @resapi/hono @resapi/sury hono sury sury-ppx
```

A shared contract, importable by both server and client:

```rescript
// AccountApi.res
open ResApi

@schema type params = {id: string}
@schema type account = {id: string, name: string, balance: float}
@schema type accountError = | @as("not_found") NotFound

let getAccount =
  Endpoint.get(
    "/accounts/:id",
    ~params=SuryCodec.make(paramsSchema),
    ~response=SuryCodec.make(accountSchema),
  )->Endpoint.withErrors(SuryCodec.make(accountErrorSchema), ~status=error =>
    switch error {
    | NotFound => 404
    }
  )
```

The server, on Hono. A router is a Hono app, so it is already a Cloudflare Worker module:

```rescript
// App.res
open ResApiHono

let accounts: dict<AccountApi.account> = dict{
  "acct_123": {id: "acct_123", name: "Savings", balance: 100.0},
}

let app: Router.t<unit> =
  Router.make()
  ->Router.get("/health", async _ctx => ResApi.Fetch.Response.text("ok"))
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      switch accounts->Dict.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )

let default = app
```

The client:

```rescript
// AccountClient.res
open ResApi

let client = Client.make(~baseUrl="https://api.example.com")

let accountName = async id =>
  switch await client->Client.call(AccountApi.getAccount, ~params={id: id}) {
  | Ok(account) => account.name
  | Error(Application({error: NotFound})) => "no such account"
  | Error(_) => "request failed"
  }
```

`Endpoint.get` also checks, when the module loads, that the route's `:id` matches the params codec. A mismatch stops the app from starting.

## Packages

| Package | Contents | Depends on |
| --- | --- | --- |
| `@resapi/core` | Contracts (`Endpoint`), codecs (`Codec`), route checking, typed `Client`, Fetch bindings | ReScript only |
| `@resapi/hono` | `Router`, `EndpointHandler`, `Context`: runs contracts on Hono | core; peer `hono` 4 |
| `@resapi/express` | `Router`, `EndpointHandler`, `Req`, `Res`: runs contracts on Express | core; peer `express` 5 |
| `@resapi/sury` | `SuryCodec.make`: Sury schema → `Codec.t` | core; peer `sury` 11 |

No adapter depends on another, and core depends on none of them. Any codec that implements the two-function `Codec.t` interface works.

## Documentation

- [Getting started](docs/getting-started.md): contract, Hono server, Cloudflare Worker, client
- [Express](docs/express.md): the same with Express 5 on Node
- [Errors](docs/errors.md): every failure the server and client report, and the wire formats
- [API reference](docs/api.md)
- [Architecture](docs/architecture.md): design decisions
- Examples: [Cloudflare Workers](examples/cloudflare), [Express](examples/express)

## Development

Requires Node 22 or later.

```bash
npm install
npm run build              # compile all ReScript
npm test                   # unit, integration and compile-fail tests (Node)
npm run test:worker        # example and probe Workers under wrangler dev (workerd)
npm run check:isolation    # package boundaries in the compiled import graph
npm run check:clean-build  # fresh clone build plus incremental-build checks
npm run check:packages     # pack, then install into fresh projects (incl. the doc examples)
npm run release:check      # every check a release needs
npm run format:check
```

After editing any `rescript.json`, run `npx rescript clean` before building.

## License

MIT, © Seaside Logic. Contributions: [CONTRIBUTING.md](CONTRIBUTING.md). Security reports: [SECURITY.md](SECURITY.md).
