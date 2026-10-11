# Express

This guide serves resAPI contracts from [Express](https://expressjs.com) 5 on Node. It assumes you have read [Getting started](getting-started.md) up to the contract. Everything about contracts and the client is the same; only the server differs.

The complete version is in [`examples/express`](../examples/express).

## Install

```bash
npm install @resapi/core @resapi/express @resapi/sury express sury sury-ppx
npm install --save-dev rescript
```

`rescript.json` lists `"@resapi/core"`, `"@resapi/express"`, `"@resapi/sury"` and `"sury"` in `dependencies`, with `"ppx-flags": ["sury-ppx/bin"]`. Modules are under the `ResApiExpress` namespace.

**Versions:** Express 5 only (tested on 5.2.1). Express 4 is not supported.

## A server

```rescript
// src/NoteApi.res
open ResApi

@schema
type params = {id: string}

@schema
type note = {id: string, text: string}

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
// src/App.res
open ResApiExpress

let notes: dict<NoteApi.note> = dict{}

let app =
  Router.make()
  ->Router.get("/health", async (_req, res) => res->Res.send("ok"))
  ->Router.register(
    NoteApi.getNote->EndpointHandler.make(async (_req, {params}) =>
      switch notes->Dict.get(params.id) {
      | Some(note) => Ok(note)
      | None => Error(NotFound)
      }
    ),
  )
  ->Router.register(
    NoteApi.createNote->EndpointHandler.make(async (_req, {body}) => {
      let id = `note_${(notes->Dict.keysToArray->Array.length + 1)->Int.toString}`
      let note: NoteApi.note = {id, text: body.text}
      notes->Dict.set(note.id, note)
      Ok(note)
    }),
  )
```

```rescript
// src/Server.res
let server = App.app->ResApiExpress.Router.listen(3000, () => Console.log("Listening on :3000"))
```

```bash
npx rescript && node src/Server.res.mjs
```

- **`Router.t` is the Express app.** Any Express API not wrapped here, such as `app.set`, binds against it with one external.
- **`Router.get`/`post`** register plain Express routes: `(req, res) => promise<unit>`.
- **`Router.register`** adds a typed endpoint. The handler gets the Express `Req.t` and the decoded `params` and `body`. It returns `Ok(response)` or `Error(declaredError)`, and resAPI sends the response.

## Request bodies

`Router.register` puts a raw-text body parser in front of each typed POST route, so resAPI parses the JSON itself and reports problems in its own format.

- **Content type.** A typed POST accepts any content type, as long as the body is valid JSON: `application/json`, `text/plain`, none at all. Behaviour is the same on Hono.
- **Don't mount body parsers globally in front of typed routes.** resAPI parses typed routes' bodies itself. An upstream `express.json()` works, and resAPI uses the body it parsed. But that parser's failures are answered by Express in Express's format, before any of your auth middleware runs if it's mounted later. Scope parsers to the plain routes that need them, for example `Router.use(~path="/webhooks", json())`.
- **Size limit.** The built-in parser keeps Express's default limit of 100kb, and an oversized body is a 413 from Express. To change the limit, mount your own parser ahead of the typed routes, for example `express.text({type: () => true, limit: "1mb"})`. resAPI uses a body that has already been read.
- **Order.** Your middleware runs first. Then `register`'s own body parser reads the body, and resAPI decodes params, then the body. A request your auth middleware rejects is never read.

## Middleware

`Router.use` takes native Express middleware, `(req, res, next) => unit`. Express's own middleware binds with one external:

```rescript
@module("express") external json: unit => ResApiExpress.Router.middleware = "json"
```

Your own middleware can read headers, reject a request, set response headers, and pass values to handlers. Use `Reject` for auth rejections, so the typed client sees `Unauthorized`, and a typed key for request-scoped values:

```rescript
// src/Auth.res
open ResApiExpress

type user = {name: string}
let userKey: ResApi.Key.t<user> = ResApi.Key.make("user")

let requireUser: Router.middleware = (req, res, next) =>
  switch req->Req.header("x-user") {
  | None => Reject.unauthenticated(res)
  | Some(name) =>
    req->Req.set(userKey, {name: name})
    res->Res.setHeader("x-served-by", "resAPI")->ignore
    next()
  }
```

Mount it with `Router.make()->Router.use(Auth.requireUser)->Router.register(...)`, and read the user in a handler with `req->Req.getOrThrow(Auth.userKey)`. A key named `"user"` also reads Passport's `req.user`.

**Pick key names Express doesn't use.** On Express, a key is a property on `req` itself, so it shares the namespace with Express's own fields. A name backed by a getter, such as `query`, `path`, `hostname`, `ip`, `protocol` or `secure`, makes `Req.set` throw a `TypeError`. A name Express or resAPI writes, such as `params`, `body`, `route` or `baseUrl`, is overwritten later in the request, or breaks what reads it. Use a distinctive name (`"user"`, `"account"`, `"apiKey"`), or one that matches the middleware you're reading from. Hono keeps `c.set` values in a separate map, so this only applies to Express.

## Routing beside typed endpoints

- **`Router.all(path, handler)`** is a plain route for every HTTP method.
- **Unmatched requests:** add a last `Router.use` that answers them. Express has no separate not-found handler.
- **`Router.assertRegistered(router, endpoints)`** throws, naming each listed contract that wasn't mounted with `register`. Call it in a test with a list of every contract (`[Api.getProject->Endpoint.any, ...]`).

## Errors

- **Typed endpoints** never reach Express's error handler. Invalid input is a 400, a declared error has its declared status, and an exception from a codec or handler is logged and answered with a 500 that reveals nothing.
- **Plain routes and middleware** follow Express: a rejected handler or a thrown exception goes to Express's error handler. resAPI rethrows ReScript exceptions as JS `Error`s so the handler logs a stack trace. Express's default handler includes the stack in the response body unless `NODE_ENV=production`.

See [Errors](errors.md) for the full list and the wire formats.
