// Hono's request context. `'env` is the runtime environment (Workers bindings), fixed per router.
type t<'env>
type honoRequest

@get external req: t<'env> => honoRequest = "req"

/** Runtime environment, e.g. Workers bindings. Its type is whatever the app's router declares;
    the runtime object itself is unchecked, like an external binding. */
@get external env: t<'env> => 'env = "env"

/** The response so far. In middleware, read it after `await next()`. */
@get external res: t<'env> => ResApi.Fetch.Response.t = "res"

/** Sets a response header, before or after `next()` (Hono's `c.header`). */
@send external setHeader: (t<'env>, string, string) => unit = "header"

@send external param: (honoRequest, string) => string = "param"
@send external allParams: honoRequest => dict<string> = "param"
@send external reqText: honoRequest => promise<string> = "text"
@send @return(nullable) external reqHeader: (honoRequest, string) => option<string> = "header"
@get external reqMethod: honoRequest => string = "method"
@get external reqPath: honoRequest => string = "path"

/** Path parameter value. Hono returns "" (not undefined) when a route declares the name. */
let param = (ctx, name) => ctx->req->param(name)
let params = ctx => ctx->req->allParams
let text = ctx => ctx->req->reqText
let header = (ctx, name) => ctx->req->reqHeader(name)
let method = ctx => ctx->req->reqMethod
let path = ctx => ctx->req->reqPath
