# Middleware and auth

This page covers middleware on Hono and Express, and protecting typed endpoints with auth. It follows on from [Getting started](getting-started.md).

`Router.use` takes the framework's native middleware, so its built-ins and third-party middleware bind with one external. Auth is ordinary middleware, mounted for a path. It runs before resAPI decodes anything, so an unauthenticated request gets its 401 before any 400, and its body is never read. Contracts don't mention auth.

resAPI adds two small helpers:

- **`Reject.unauthenticated(~reason=?)`** (401) and **`Reject.forbidden(~reason=?)`** (403) answer in resAPI's error shape, `{"error": {"kind": "unauthenticated", "message": "invalid_token", "path": []}}`. The typed client sees `Error(Unauthorized({status, reason}))`, here with `reason: Some("invalid_token")`, so the UI can word each reason. Any other middleware's 401 or 403 is `Unauthorized` too, with `reason: None`.
- **A key** passes a typed value, such as the signed-in user, from middleware to handlers. The middleware sets it and the handler reads it with `getOrThrow`, which throws when the value is missing: that means the middleware isn't mounted for that path, and inside a typed endpoint it becomes a logged 500 that reveals nothing. `get` returns an `option` for routes where the value is optional.

This contract is protected in the examples below:

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

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

Hono middleware has the shape `(ctx, next) => promise<option<Response>>`. Hono's built-ins bind with one external:

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
- **Paths.** `~path="/accounts/*"` covers `/accounts` and everything under it, but not `/accountsx`. Without `~path`, middleware runs for every request, including unmatched ones.
- **After `next()`.** `Context.res` is the response so far, and `Context.setHeader` still sets headers. An exception from a handler has already become a 500 by then, so middleware can't catch it.

Bearer-token auth, and a server that uses it:

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

Keys use Hono's per-request map (`c.set`/`c.get`), separate from the request object, so a key's name can't clash with Hono's own fields.

Hono's own auth middleware works too, and the client sees its 401s and 403s as `Unauthorized` with `reason: None`. Two details:

- **`hono/bearer-auth`** answers a malformed `Authorization` header (`Bearer` with no token, say) with 400, not 401. The client sees that as `UnexpectedStatus`.
- **Values third-party middleware sets** are read with a key of the same name. `hono/jwt` stores the verified payload under `"jwtPayload"`, so `let payloadKey: ResApi.Key.t<Claims.t> = ResApi.Key.make("jwtPayload")` reads it. The type is your declaration: resAPI doesn't check the value.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

Express middleware has the shape `(req, res, next) => unit`. Express's own middleware binds with one external:

```rescript
@module("express") external json: unit => ResApiExpress.Router.middleware = "json"
```

Your own middleware can read headers, reject a request, set response headers, and pass values to handlers. Middleware runs in registration order, so register it before the routes it protects.

Bearer-token auth, and a server that uses it:

```rescript
// src/BearerAuth.res
open ResApiExpress

type user = {name: string}

// The type is declared here; middleware stores the value, handlers read it back.
let userKey: ResApi.Key.t<user> = ResApi.Key.make("user")

let requireToken: Router.middleware = (req, res, next) =>
  switch req->Req.header("authorization") {
  | None => Reject.unauthenticated(res)
  | Some("Bearer secret-token") =>
    req->Req.set(userKey, {name: "Ada"})
    res->Res.setHeader("x-served-by", "resAPI")->ignore
    next()
  | Some(_) => Reject.unauthenticated(res, ~reason="invalid_token")
  }
```

```rescript
// src/ProfileServer.res
open ResApiExpress

let app =
  Router.make()
  ->Router.use(~path="/me", BearerAuth.requireToken)
  ->Router.register(
    ProfileApi.getProfile->EndpointHandler.make(async (req, _) =>
      Ok({ProfileApi.name: (req->Req.getOrThrow(BearerAuth.userKey)).name})
    ),
  )
```

A key named `"user"` also reads Passport's `req.user`.

**Pick key names Express doesn't use.** On Express, a key is a property on `req` itself, so it shares the namespace with Express's own fields. A name backed by a getter, such as `query`, `path`, `hostname`, `ip`, `protocol` or `secure`, makes `Req.set` throw a `TypeError`. A name Express or resAPI writes, such as `params`, `body`, `route` or `baseUrl`, is overwritten later in the request, or breaks what reads it. Use a distinctive name (`"user"`, `"account"`, `"apiKey"`), or one that matches the middleware you're reading from. Hono keeps `c.set` values in a separate map, so this only applies to Express.

</div>
