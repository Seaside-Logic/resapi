// A router is the Hono app itself, so a Worker can `export default` it and any Hono API missing here
// can be bound against `t` with one more external. `'env` is the bindings type handlers see.

type t<'env>

/** Handlers are always async: `async ctx => Fetch.Response.fromString("hi")`. */
type handler<'env> = Context.t<'env> => promise<ResApi.Fetch.Response.t>

type next = unit => promise<unit>

/** Native Hono middleware: `await next()` to continue, then return `None`; return `Some(response)`
    to answer without calling the rest. Hono's built-in middleware binds to this type directly. */
type middleware<'env> = (Context.t<'env>, next) => promise<option<ResApi.Fetch.Response.t>>

@module("hono") @new external make: unit => t<'env> = "Hono"

let get: (t<'env>, string, handler<'env>) => t<'env>
let post: (t<'env>, string, handler<'env>) => t<'env>

/** Runs for every request whose path matches `~path` (Hono pattern, default all), including unmatched
    routes. The first `use` is the outermost layer. */
let use: (t<'env>, ~path: string=?, middleware<'env>) => t<'env>

let register: (t<'env>, EndpointHandler.route<'env>) => t<'env>

/** Fetch API entry point, for in-process calls and tests. */
@send
external fetch: (t<'env>, ResApi.Fetch.Request.t, 'env) => promise<ResApi.Fetch.Response.t> =
  "fetch"
