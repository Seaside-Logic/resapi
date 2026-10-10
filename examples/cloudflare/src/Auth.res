// Bearer auth with Hono's own middleware. The token comes from the typed API_SECRET binding, so the
// middleware is built per request (Hono's documented pattern for env-dependent options).
open ResApiHono

type bearerOptions = {token: string}
@module("hono/bearer-auth")
external bearerAuth: bearerOptions => Router.middleware<'env> = "bearerAuth"

let bearer: Router.middleware<Env.t> = (ctx, next) =>
  bearerAuth({token: (ctx->Context.env).apiSecret})(ctx, next)
