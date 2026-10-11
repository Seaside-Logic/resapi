# Hono

This guide covers serving resAPI contracts from [Hono](https://hono.dev) 4, on Cloudflare Workers or anywhere else Hono runs. [Getting started](getting-started.md) walks through a first endpoint step by step. This page collects the Hono adapter's details in one place: the router, middleware and auth, request bodies, routing beside typed endpoints, Workers, and errors.

The complete Workers example is in [`examples/cloudflare`](../examples/cloudflare).

## Install

```bash
npm install @resapi/core @resapi/hono @resapi/sury hono sury sury-ppx
npm install --save-dev rescript wrangler
```

`rescript.json` lists `"@resapi/core"`, `"@resapi/hono"`, `"@resapi/sury"` and `"sury"` in `dependencies`, with `"ppx-flags": ["sury-ppx/bin"]`. Modules are under the `ResApiHono` namespace. `wrangler` is only needed for Workers.

**Versions:** Hono 4 (tested on 4.13.13). resAPI is tested in workerd and by calling the app in-process under Node.

## A server

A contract, auth middleware, the app, and the Worker entry:

```rescript
// src/NoteApi.res
open ResApi

@schema
type params = {id: string}

@schema
type note = {id: string, text: string, author: string}

@schema
type newNote = {text: string}

@schema
type noteError = | @as("not_found") NotFound

let noteCodec = SuryCodec.make(noteSchema)

let getNote = Endpoint.get(
  "/notes/:id",
  ~params=SuryCodec.make(paramsSchema),
  ~response=noteCodec,
)->Endpoint.withErrors(SuryCodec.make(noteErrorSchema), ~status=error =>
  switch error {
  | NotFound => 404
  }
)

let createNote = Endpoint.post(
  "/notes",
  ~params=Codec.unit,
  ~body=SuryCodec.make(newNoteSchema),
  ~response=noteCodec,
)
```

```rescript
// src/Auth.res
open ResApiHono

type user = {name: string}

// Middleware stores the signed-in user under this key; handlers read it back.
let userKey: ResApi.Key.t<user> = ResApi.Key.make("user")

let requireToken: Router.middleware<'env> = async (ctx, next) =>
  switch ctx->Context.header("authorization") {
  | Some("Bearer secret-token") =>
    ctx->Context.set(userKey, {name: "Ada"})
    await next()
    None
  | Some(_) => Some(Reject.unauthenticated(~reason="invalid_token"))
  | None => Some(Reject.unauthenticated())
  }
```

```rescript
// src/App.res
open ResApi
open ResApiHono

type bodyLimitOptions = {maxSize: int}
@module("hono/body-limit")
external bodyLimit: bodyLimitOptions => Router.middleware<'env> = "bodyLimit"

let notes: dict<NoteApi.note> = dict{}

let app: Router.t<unit> =
  Router.make()
  // Middleware first: Hono runs handlers in registration order.
  ->Router.use(~path="/notes/*", Auth.requireToken)
  ->Router.use(~path="/notes/*", bodyLimit({maxSize: 1024}))
  ->Router.get("/health", async _ctx => Fetch.Response.fromString("ok"))
  ->Router.register(
    NoteApi.getNote->EndpointHandler.make(async (_ctx, {params}) =>
      switch notes->Dict.get(params.id) {
      | Some(note) => Ok(note)
      | None => Error(NotFound)
      }
    ),
  )
  ->Router.register(
    NoteApi.createNote->EndpointHandler.make(async (ctx, {body}) => {
      let id = `note_${(notes->Dict.keysToArray->Array.length + 1)->Int.toString}`
      let author = (ctx->Context.getOrThrow(Auth.userKey)).name
      let note: NoteApi.note = {id, text: body.text, author}
      notes->Dict.set(note.id, note)
      Ok(note)
    }),
  )
  ->Router.notFound(async _ctx =>
    Fetch.Response.jsonR(
      ~data=JSON.Encode.object(dict{"error": JSON.Encode.string("not_found")}),
      ~init={status: 404},
    )
  )
```

```rescript
// src/Worker.res
let default = App.app
```

```bash
npx rescript && npx wrangler dev
```

- **`Router.t` is the Hono app.** `Router.make()` is `new Hono()`, so the router is a valid Worker default export, and any Hono API resAPI doesn't wrap (`app.onError`, `app.route`, ...) binds against `Router.t` with one external.
- **`Router.get`/`post`** register plain Hono routes: the context in, a Fetch `Response` out.
- **`Router.register`** adds a typed endpoint. The handler gets the Hono context and the decoded `params` and `body`. It returns `Ok(response)` or `Error(declaredError)`, and resAPI sends the response.

## The `'env` type

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

## Middleware

`Router.use` takes native Hono middleware, `(ctx, next) => promise<option<Response>>`. Hono's built-ins bind with one external:

```rescript
@module("hono/logger") external logger: unit => Router.middleware<'env> = "logger"
```

Your own middleware has the same shape. Call `await next()` and return `None` to continue, or return `Some(response)` to answer without running the rest:

```rescript
let poweredBy: Router.middleware<'env> = async (ctx, next) => {
  await next()
  ctx->Context.setHeader("x-powered-by", "resAPI")
  None
}
```

- **Order.** Middleware and routes run in registration order, with the first `use` as the outermost layer. Middleware registered *after* a route doesn't run for it, so register it first.
- **Paths.** `~path="/notes/*"` covers `/notes` and everything under it, but not `/notesx`. Without `~path`, middleware runs for every request, including unmatched ones.
- **After `next()`.** `Context.res` is the response so far, and `Context.setHeader` still sets headers. An exception from a handler has already become a 500 by then, so middleware can't catch it.

### Auth

Auth is ordinary middleware, mounted for a path. It runs before resAPI decodes anything, so an unauthenticated request gets its 401 before any 400, and its body is never read. Contracts don't mention auth. `Auth.requireToken` above shows both helpers resAPI adds:

- **`Reject.unauthenticated(~reason=?)`** (401) and **`Reject.forbidden(~reason=?)`** (403) answer in resAPI's error shape, `{"error": {"kind": "unauthenticated", "message": "invalid_token", "path": []}}`. The typed client sees `Error(Unauthorized({status, reason}))`, here with `reason: Some("invalid_token")`, so the UI can word each reason.
- **A key** passes a typed value from middleware to handlers: `Context.set(key, value)` in the middleware, `Context.getOrThrow(key)` in the handler. `getOrThrow` throws when the value is missing, which means the middleware isn't mounted for that path. Inside a typed endpoint that's a logged 500 that reveals nothing. `Context.get` returns an `option` for routes where the value is optional.

Hono's own auth middleware works too, and the client sees its 401s and 403s as `Unauthorized` with `reason: None`. Two details:
- **`hono/bearer-auth`** answers a malformed `Authorization` header (`Bearer` with no token, say) with 400, not 401. The client sees that as `UnexpectedStatus`.
- **Values third-party middleware sets** are read with a key of the same name. `hono/jwt` stores the verified payload under `"jwtPayload"`, so `let payloadKey: ResApi.Key.t<Claims.t> = ResApi.Key.make("jwtPayload")` reads it. The type is your declaration: resAPI doesn't check the value.

Keys live in Hono's per-request map (`c.set`/`c.get`), separate from the request object, so a key's name can't clash with Hono's own fields.

## Request bodies

resAPI reads a typed POST's body itself (`c.req.text()`), only after the path params have decoded.

- **Content type.** Any content type is accepted, as long as the body is valid JSON. resAPI never answers 415.
- **Size limit.** resAPI sets none, and Workers caps request bodies per plan. For your own limit, mount Hono's `bodyLimit` in front of the typed routes, as the example does. It answers an oversized body with Hono's plain-text 413, which the client sees as `UnexpectedStatus`, whether or not the request sends a `content-length`. Mounted after `Auth.requireToken`, it only runs for authenticated requests.

## Routing beside typed endpoints

- **`Router.all(path, handler)`** is a plain route for every HTTP method. It's how you hand a prefix to another library, for example `Router.all("/api/auth/*", ...)` for Better Auth.
- **`Context.request`** is the original Fetch `Request` (`c.req.raw`), for libraries that take one: `auth->BetterAuth.handler(ctx->Context.request)`. Bind such libraries against `ResApi.Fetch` types.
- **`Router.notFound(handler)`** answers unmatched requests, as in the example. Without it, Hono answers a plain-text 404.
- **`Router.assertRegistered(router, endpoints)`** throws, naming each listed contract that wasn't mounted with `register`. Keep a list of every contract (`[NoteApi.getNote->Endpoint.any, ...]`) and call it in a test, so a forgotten `register` fails the test instead of answering 404.

## Workers

- **No glue.** `let default = App.app` is the whole Worker entry. No JavaScript file or compatibility flags are needed.
- **Build codecs at module top level.** `SuryCodec.make` compiles validators with `new Function`, which Workers forbid once a request is running. A codec built inside a handler works under Node and fails on Workers.
- **Testing.** `Router.fetch(app, request, env)` calls the app in-process, so a client test can use `Client.make(~baseUrl="http://localhost", ~fetch=request => App.app->Router.fetch(request, ()))`. That runs routing, middleware, validation and codecs, but not Workers' restrictions. Run the same tests against `wrangler dev` too (see `scripts/test-worker.sh` in this repo).

## Errors

- **Typed endpoints** never reach Hono's `onError`. Invalid input is a 400, a declared error has its declared status, and an exception from a codec or handler is logged and answered with a 500 that reveals nothing.
- **Plain routes and middleware** follow Hono: an exception goes to `onError`, whose default logs it and answers a plain 500. Hono only handles JS `Error`s, so resAPI rethrows raw ReScript exceptions from `Router.get`/`post`/`use` as JS `Error`s. JS errors, including Hono's `HTTPException`, pass through untouched.

See [Errors](errors.md) for the full list and the wire formats.
