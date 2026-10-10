// A router is the Express app itself, so any Express API missing here can be bound against `t` with one
// more external. Express 5 sends a rejected handler promise to its error handler (by default: log, then
// a 500; outside production the body shows the stack, as Express always does).

type t

/** Handlers are always async: `async (_req, res) => res->Res.send("hi")`. */
type handler = (Req.t, Res.t) => promise<unit>

type next = unit => unit

/** Native Express middleware: call `next()` to continue, or answer through `res`. Express's own
    middleware (`express.json()`, `express.static(...)`) binds to this type directly. */
type middleware = (Req.t, Res.t, next) => unit

type server

@module("express") external make: unit => t = "default"
@module("express") external text: {"type": string => bool} => middleware = "text"
@send external expressGet: (t, string, handler) => unit = "get"
@send external expressPost: (t, string, handler) => unit = "post"
@send external expressPostWith: (t, string, middleware, handler) => unit = "post"
@send external expressUse: (t, middleware) => unit = "use"
@send external expressUseAt: (t, string, middleware) => unit = "use"

/** Starts a Node HTTP server. Port 0 picks a free port. */
@send external listen: (t, int, unit => unit) => server = "listen"
@send external close: server => unit = "close"

// Express's error handler logs `err.stack`, which a raw ReScript exception lacks: it logs as
// "[object Object]". Rethrowing it as an Error keeps the log readable. JS errors pass untouched.
let rethrowAsError = exn =>
  switch exn {
  | JsExn(e) => JsExn.throw(e)
  | exn =>
    JsError.throwWithMessage(
      `Uncaught ReScript exception: ${exn->JSON.stringifyAny->Option.getOr("unknown")}`,
    )
  }

let guard = (handler: handler): handler =>
  async (req, res) =>
    try await handler(req, res) catch {
    | exn => rethrowAsError(exn)
    }

let get = (router, path, handler) => {
  router->expressGet(path, guard(handler))
  router
}

let post = (router, path, handler) => {
  router->expressPost(path, guard(handler))
  router
}

/** Runs for every request whose path starts with `~path` (default all), including unmatched routes.
    The first `use` is the outermost layer. */
let use = (router, ~path=?, middleware: middleware) => {
  let guarded = (req, res, next) =>
    try middleware(req, res, next) catch {
    | exn => rethrowAsError(exn)
    }
  switch path {
  | None => router->expressUse(guarded)
  | Some(path) => router->expressUseAt(path, guarded)
  }
  router
}

// Reads any request body as raw text, so Dispatch reports malformed JSON itself. It skips a body an
// upstream parser already read.
let rawText = text({"type": _ => true})

let register = (router, route: EndpointHandler.route) => {
  switch route.method {
  | Get => router->expressGet(route.path, route.run)
  | Post => router->expressPostWith(route.path, rawText, route.run)
  }
  router
}
