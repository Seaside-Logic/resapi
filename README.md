# resAPI

_Type-safe HTTP contracts for ReScript._

Define an HTTP endpoint once as a contract: method, path, and codecs for params, body, response and declared errors. Servers and clients both import that contract. The compiler checks handlers and calls against it, and the codecs validate every request and response at runtime.

Website (planned): https://resapi.dev

> **Status: early development.** Nothing is published to npm yet, and the API may change before a first preview release.

## Why

- **One definition, both sides.** The server handler and the client call get their types from the same contract value, with no generated code.
- **Runtime validation at both boundaries.** The server decodes params and bodies before your handler runs. The client decodes responses before you see them, with no casts.
- **Compile-time checking.** Wrong param fields, wrong body types, wrong handler results and undeclared errors are compile errors.
- **Typed application errors.** An endpoint declares its expected failures (`NotFound`, `AccessDenied`) and their HTTP statuses. They stay separate from network, validation and server errors.
- **Runtime independence.** Contracts and the client depend only on Fetch. Server adapters exist for Hono (runs on Cloudflare Workers with no JS glue) and Express (Node).

## Example

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

The server:

```rescript
// App.res
open ResApiHono

let app: Router.t<unit> =
  Router.make()
  ->Router.get("/health", async _ctx => ResApi.Fetch.Response.text("ok"))
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      switch AccountStore.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )

// Worker.res: a router is a Hono app, which is already a Worker module.
let default = App.app
```

The client:

```rescript
open ResApi

let client = Client.make(~baseUrl="https://api.example.com")

switch await client->Client.call(AccountApi.getAccount, ~params={id: "acct_123"}) {
| Ok(account) => Console.log(account.name)
| Error(Application({error: NotFound})) => Console.log("no such account")
| Error(Network(message)) => Console.error(message)
| Error(_) => Console.error("request failed")
}
```

`Endpoint.get` also checks, when the module loads, that the route's `:id` matches the params codec. A mismatch stops the app from starting.

## Packages

| Package | Contents | Depends on |
| --- | --- | --- |
| `@resapi/core` | Contracts (`Endpoint`), codecs (`Codec`), route checking, typed `Client`, Fetch bindings | ReScript only |
| `@resapi/hono` | `Router`, `EndpointHandler`, `Context`: runs contracts on Hono | core, `hono` |
| `@resapi/express` | `Router`, `EndpointHandler`, `Req`, `Res`: runs contracts on Express | core, `express` |
| `@resapi/sury` | `SuryCodec.make`: Sury schema → `Codec.t` | core, `sury` |

No adapter depends on another, and core depends on none of them. Any codec that implements the two-function `Codec.t` interface works.

## Documentation

- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [API reference](docs/api.md)
- [Cloudflare example](examples/cloudflare)

## Development

Requires Node 22 or later.

```bash
npm install
npm run build              # compile all ReScript
npm test                   # unit, integration and compile-fail tests (Node)
npm run test:worker        # example and probe Workers under wrangler dev (workerd)
npm run check:isolation    # package boundaries in the compiled import graph
npm run check:clean-build  # fresh clone build plus incremental-build checks
npm run format:check
```

After editing any `rescript.json`, run `npx rescript clean` before building.

## License

MIT
