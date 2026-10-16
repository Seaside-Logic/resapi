# Middleware and auth

This page builds on [Getting started](getting-started.md) and shows how to use middleware to protect typed endpoints on Hono and Express.

`Router.use` accepts the framework's native middleware. To use built-in or third-party middleware, define a ReScript external for it. Register auth middleware for the paths you want to protect, before adding the routes. It can reject an unauthenticated request with a 401 before resAPI validates the parameters or reads the body. Auth stays in the server setup; contracts don't need to declare it.

resAPI provides two helpers for auth middleware:

- **`Reject.unauthenticated(~reason=?)`** (401) and **`Reject.forbidden(~reason=?)`** (403) return responses in resAPI's error format, for example `{"error": {"kind": "unauthenticated", "message": "invalid_token", "path": []}}`. The typed client receives `Error(Unauthorized({status, reason}))`. In this example, `reason` is `Some("invalid_token")`, which lets your UI choose an appropriate message. A 401 or 403 from other middleware is also reported as `Unauthorized`, usually with `reason: None`.
- **A key** passes a typed value, such as the signed-in user, from middleware to a handler. The middleware sets the value, and the handler reads it with `getOrThrow`. A missing value usually means the middleware wasn't registered for that path. In a typed endpoint, the resulting exception is logged and returned as HTTP 500 without exposing its details. For optional values, use `get`, which returns an `option`.

The examples below protect an endpoint with this contract:

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

Hono middleware has the signature `(ctx, next) => promise<option<Response>>`. You can bind built-in middleware with a ReScript external:

```rescript
@module("hono/logger") external logger: unit => Router.middleware<'env> = "logger"
```

Use the same signature for your own middleware. Call `await next()` to run the remaining middleware and handler, then return `None`. To respond immediately, return `Some(response)` without calling `next()`:

```rescript
let poweredBy: Router.middleware<'env> = async (ctx, next) => {
  await next()
  ctx->Context.setHeader("x-powered-by", "resAPI")
  None
}
```

- **Order.** Register middleware before the routes that need it. Middleware and routes run in registration order, with the first `use` forming the outermost layer.
- **Paths.** `~path="/accounts/*"` matches `/accounts` and everything under it, but not `/accountsx`. Omit `~path` to run middleware for every request, including requests that match no route.
- **After `next()`.** Use `Context.res` to read the response and `Context.setHeader` to add headers. By this point, handler exceptions have already been converted to responses, so middleware can inspect the response but cannot catch the original exception.

Here is a bearer-token middleware and a server that uses it:

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

Keys use Hono's per-request map (`c.set`/`c.get`). This map is separate from the request object, so key names don't conflict with Hono's request fields.

You can also use Hono's auth middleware. The client reports its 401 and 403 responses as `Unauthorized` with `reason: None`. Keep two details in mind:

- **`hono/bearer-auth`** returns HTTP 400 for a malformed `Authorization` header, such as `Bearer` without a token. The client reports this as `UnexpectedStatus`.
- **Read values from third-party middleware with a key of the same name.** For example, `hono/jwt` stores the verified payload under `"jwtPayload"`. Declare `let payloadKey: ResApi.Key.t<Claims.t> = ResApi.Key.make("jwtPayload")` to read it. You are responsible for choosing the correct type; resAPI doesn't validate the stored value.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

Express middleware has the signature `(req, res, next) => unit`. You can bind built-in middleware with a ReScript external:

```rescript
@module("express") external json: unit => ResApiExpress.Router.middleware = "json"
```

Your middleware can read request headers, reject requests, set response headers, and pass values to handlers. Call `next()` to continue processing. Middleware runs in registration order, so register it before the routes it protects.

Here is a bearer-token middleware and a server that uses it:

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

You can also use keys to read values set by other middleware. For example, a key named `"user"` reads Passport's `req.user`.

**Choose key names that don't conflict with Express.** Express stores keyed values directly on `req`, alongside its own fields. Using a getter property such as `query`, `path`, `hostname`, `ip`, `protocol`, or `secure` causes `Req.set` to throw a `TypeError`. Fields such as `params`, `body`, `route`, and `baseUrl` may be overwritten during the request, and changing them can break later handlers. Choose a distinct name, such as `"user"`, `"account"`, or `"apiKey"`, or use the name expected by the middleware you're integrating with. This restriction applies only to Express; Hono stores keyed values in a separate map.

</div>
