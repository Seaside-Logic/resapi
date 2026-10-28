// A router is the Express app itself, so any Express API missing here can be bound against `t` with one
// more external.

type t

/** Handlers are always async: `async (_req, res) => res->Res.send("hi")`. */
type handler = (Req.t, Res.t) => promise<unit>

type next = unit => unit

/** Native Express middleware: call `next()` to continue, or answer through `res`. Express's own
    middleware (`express.json()`, `express.static(...)`) binds to this type directly. */
type middleware = (Req.t, Res.t, next) => unit

type server

@module("express") external make: unit => t = "default"

/** Starts a Node HTTP server. Port 0 picks a free port. */
@send external listen: (t, int, unit => unit) => server = "listen"
@send external close: server => unit = "close"

/** A rejected handler goes to Express's error handler. */
let get: (t, string, handler) => t
let post: (t, string, handler) => t
let put: (t, string, handler) => t

/** Runs for every request whose path starts with `~path` (default all), including unmatched routes.
    The first `use` is the outermost layer. */
let use: (t, ~path: string=?, middleware) => t

/** POST and PUT endpoints get a raw-text body parser (100kb limit). A body already parsed upstream is used as is. */
let register: (t, EndpointHandler.route) => t

/** A plain route for every HTTP method. For unmatched requests, add a last `use` (Express has no
    separate not-found handler). */
let all: (t, string, handler) => t

/** For tests: throws, naming each endpoint in the list that wasn't mounted with `register`. */
let assertRegistered: (t, array<ResApi.Endpoint.any>) => unit
