// Hono's request context. `'env` is the runtime environment (Workers bindings), fixed per router.
type t<'env>
type honoRequest

@get external req: t<'env> => honoRequest = "req"

@get external env: t<'env> => 'env = "env"

@get external res: t<'env> => ResApi.Fetch.Response.t = "res"

@send external setHeader: (t<'env>, string, string) => unit = "header"

@send external param: (honoRequest, string) => string = "param"
@send external allParams: honoRequest => dict<string> = "param"
@send external reqText: honoRequest => promise<string> = "text"
@send @return(nullable) external reqHeader: (honoRequest, string) => option<string> = "header"
@get external reqMethod: honoRequest => string = "method"
@get external reqPath: honoRequest => string = "path"
@get external reqRaw: honoRequest => ResApi.Fetch.Request.t = "raw"

let param = (ctx, name) => ctx->req->param(name)
let params = ctx => ctx->req->allParams
let text = ctx => ctx->req->reqText
let header = (ctx, name) => ctx->req->reqHeader(name)
let method = ctx => ctx->req->reqMethod
let path = ctx => ctx->req->reqPath
let request = ctx => ctx->req->reqRaw
