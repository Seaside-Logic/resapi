// A router is the Express app itself, so any Express API missing here can be bound against `t` with one
// more external. Express 5 sends a rejected handler promise to its error handler (by default: log, then
// a 500; outside production the body shows the stack, as Express always does).

type t

type handler = (Req.t, Res.t) => promise<unit>

type next = unit => unit

type middleware = (Req.t, Res.t, next) => unit

type server

@module("express") external make: unit => t = "default"
@module("express") external text: {"type": string => bool} => middleware = "text"
@send external expressGet: (t, string, handler) => unit = "get"
@send external expressPost: (t, string, handler) => unit = "post"
@send external expressAll: (t, string, handler) => unit = "all"
@send external expressPostWith: (t, string, middleware, handler) => unit = "post"
@send external expressUse: (t, middleware) => unit = "use"
@send external expressUseAt: (t, string, middleware) => unit = "use"

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

let catchExceptions = (handler: handler): handler =>
  async (req, res) =>
    try await handler(req, res) catch {
    | exn => rethrowAsError(exn)
    }

let get = (router, path, handler) => {
  router->expressGet(path, catchExceptions(handler))
  router
}

let post = (router, path, handler) => {
  router->expressPost(path, catchExceptions(handler))
  router
}

let all = (router, path, handler) => {
  router->expressAll(path, catchExceptions(handler))
  router
}

let use = (router, ~path=?, middleware: middleware) => {
  let wrapped = (req, res, next) =>
    try middleware(req, res, next) catch {
    | exn => rethrowAsError(exn)
    }
  switch path {
  | None => router->expressUse(wrapped)
  | Some(path) => router->expressUseAt(path, wrapped)
  }
  router
}

// Reads any request body as raw text, so Dispatch reports malformed JSON itself. It skips a body an
// upstream parser already read.
let rawText = text({"type": _ => true})

// Express has no public route list, so `register` records what it mounted, for assertRegistered.
let registered: WeakMap.t<t, array<string>> = WeakMap.make()

let routeName = (method, path) => `${ResApi.Endpoint.methodName(method)} ${path}`

let register = (router, route: EndpointHandler.route) => {
  let names = registered->WeakMap.get(router)->Option.getOr([])
  registered->WeakMap.set(router, [...names, routeName(route.method, route.path)])->ignore
  switch route.method {
  | Get => router->expressGet(route.path, route.run)
  | Post => router->expressPostWith(route.path, rawText, route.run)
  }
  router
}

let assertRegistered = (router, endpoints: array<ResApi.Endpoint.any>) => {
  let names = registered->WeakMap.get(router)->Option.getOr([])
  let missing =
    endpoints
    ->Array.map(endpoint => routeName(endpoint.method, endpoint.path))
    ->Array.filter(name => !(names->Array.includes(name)))
  if missing != [] {
    JsError.throwWithMessage(`Endpoints without a route: ${missing->Array.join(", ")}`)
  }
}
