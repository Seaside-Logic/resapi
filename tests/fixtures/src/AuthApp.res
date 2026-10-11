// Servers for tests/auth.test.mjs (Hono): auth as middleware, with typed keys.
open ResApi
open ResApiHono

type user = {name: string}

let userKey: Key.t<user> = Key.make("user")

// x-user: none → 401, "mallory" → 403 with a reason, "eve" → 403 without one, otherwise the user.
let requireUser: Router.middleware<unit> = async (ctx, next) =>
  switch ctx->Context.header("x-user") {
  | None => Some(Reject.unauthenticated())
  | Some("mallory") => Some(Reject.forbidden(~reason="banned"))
  | Some("eve") => Some(Reject.forbidden())
  | Some(name) =>
    ctx->Context.set(userKey, {name: name})
    await next()
    None
  }

// Sets a value with Hono's own c.set, as third-party middleware (e.g. hono/jwt) does.
@send external honoSet: (Context.t<'env>, string, string) => unit = "set"
let tenantKey: Key.t<string> = Key.make("tenant")
let thirdParty: Router.middleware<unit> = async (ctx, next) => {
  ctx->honoSet("tenant", "acme")
  await next()
  None
}

let app: Router.t<unit> =
  Router.make()
  ->Router.use(~path="/accounts/*", requireUser)
  ->Router.use(~path="/tenant", thirdParty)
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (ctx, {params}) => Ok({
      id: params.id,
      name: (ctx->Context.getOrThrow(userKey)).name,
    })),
  )
  ->Router.get("/tenant", async ctx =>
    Fetch.Response.fromString(ctx->Context.get(tenantKey)->Option.getOr("none"))
  )
  ->Router.get("/no-tenant", async ctx =>
    Fetch.Response.fromString(ctx->Context.get(tenantKey)->Option.getOr("none"))
  )

// The route is registered before the middleware: Hono runs handlers in registration order, so the
// middleware never runs for it, and getOrThrow turns the missing user into an opaque 500.
let lateApp: Router.t<unit> =
  Router.make()
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (ctx, {params}) => Ok({
      id: params.id,
      name: (ctx->Context.getOrThrow(userKey)).name,
    })),
  )
  ->Router.use(~path="/accounts/*", requireUser)
