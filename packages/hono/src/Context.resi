// Hono's request context. `'env` is the runtime environment (Workers bindings), fixed per router.
type t<'env>

/** Runtime environment, e.g. Workers bindings. Its type is whatever the app's router declares;
    the runtime object itself is unchecked, like an external binding. */
@get external env: t<'env> => 'env = "env"

/** The response so far. In middleware, read it after `await next()`. */
@get external res: t<'env> => ResApi.Fetch.Response.t = "res"

/** Sets a response header, before or after `next()` (Hono's `c.header`). */
@send external setHeader: (t<'env>, string, string) => unit = "header"

/** Path parameter value. Hono returns "" (not undefined) when a route declares the name. */
let param: (t<'env>, string) => string
let params: t<'env> => dict<string>

/** The request body as text. */
let text: t<'env> => promise<string>

/** A request header. */
let header: (t<'env>, string) => option<string>
let method: t<'env> => string
let path: t<'env> => string

/** The original Fetch Request (Hono's `c.req.raw`), for libraries that work on Fetch requests. */
let request: t<'env> => ResApi.Fetch.Request.t
