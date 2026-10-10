// Router for tests/middleware.test.mjs: ordering, short-circuiting, exceptions and Hono's own middleware.
open ResApi
open ResApiHono

// Hono's built-in middleware fits Router.middleware as-is: binding one is a single external.
@module("hono/logger") external honoLogger: (string => unit) => Router.middleware<'env> = "logger"
type bearerOptions = {token: string}
@module("hono/bearer-auth")
external bearerAuth: bearerOptions => Router.middleware<'env> = "bearerAuth"

let events: array<string> = []
let logLines: array<string> = []

let trace = (name): Router.middleware<'env> =>
  async (_ctx, next) => {
    events->Array.push(`${name}:before`)
    await next()
    events->Array.push(`${name}:after`)
    None
  }

let poweredBy: Router.middleware<'env> = async (ctx, next) => {
  await next()
  ctx->Context.setHeader("x-powered-by", "resAPI")
  None
}

let deny: Router.middleware<'env> = async (_ctx, _next) => Some(
  Fetch.Response.text("denied", ~init={status: 403}),
)

let throwingMiddleware: Router.middleware<'env> = async (_ctx, _next) => throw(Failure("boom"))

let app: Router.t<unit> =
  Router.make()
  ->Router.use(honoLogger(line => logLines->Array.push(line)))
  ->Router.use(poweredBy)
  ->Router.use(trace("outer"))
  ->Router.use(trace("inner"))
  ->Router.use(~path="/denied", deny)
  ->Router.use(~path="/protected", bearerAuth({token: "secret"}))
  ->Router.use(~path="/middleware-throws", throwingMiddleware)
  ->Router.get("/ok", async _ctx => {
    events->Array.push("handler")
    Fetch.Response.text("ok")
  })
  ->Router.get("/denied", async _ctx => {
    events->Array.push("handler")
    Fetch.Response.text("should not run")
  })
  ->Router.get("/protected", async _ctx => Fetch.Response.text("secret"))
  ->Router.get("/middleware-throws", async _ctx => Fetch.Response.text("should not run"))
  ->Router.get("/uncaught-rescript", async _ctx => throw(Failure("boom")))
  ->Router.get("/uncaught-js", async _ctx => JsError.throwWithMessage("boom"))
  ->Router.get("/uncaught-typed", async _ctx => throw(Not_found))
