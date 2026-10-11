// A router is the Hono app itself, so a Worker can `export default` it and any Hono API missing here
// can be bound against `t` with one more external. `'env` is the bindings type handlers see.
open ResApi

type t<'env>

type handler<'env> = Context.t<'env> => promise<Fetch.Response.t>

type next = unit => promise<unit>

type middleware<'env> = (Context.t<'env>, next) => promise<option<Fetch.Response.t>>

@module("hono") @new external make: unit => t<'env> = "Hono"
@send external honoGet: (t<'env>, string, handler<'env>) => t<'env> = "get"
@send external honoPost: (t<'env>, string, handler<'env>) => t<'env> = "post"
@send external honoUse: (t<'env>, middleware<'env>) => t<'env> = "use"
@send external honoUseAt: (t<'env>, string, middleware<'env>) => t<'env> = "use"
@send external honoAll: (t<'env>, string, handler<'env>) => t<'env> = "all"
@send external honoNotFound: (t<'env>, handler<'env>) => t<'env> = "notFound"

type honoRoute = {method: string, path: string}
@get external routes: t<'env> => array<honoRoute> = "routes"

@send external fetch: (t<'env>, Fetch.Request.t, 'env) => promise<Fetch.Response.t> = "fetch"

// Hono's error handling only recognises JS Errors and rethrows anything else out of `fetch`, so a
// ReScript exception would fail the request with no response. Rethrowing it as an Error leaves Hono's
// onError (by default: log, then a plain 500) in charge. JS errors, such as HTTPException, pass untouched.
let rethrowAsError = exn =>
  switch exn {
  | JsExn(e) => JsExn.throw(e)
  | exn =>
    JsError.throwWithMessage(
      `Uncaught ReScript exception: ${exn->JSON.stringifyAny->Option.getOr("unknown")}`,
    )
  }

let catchExceptions = (handler: handler<'env>): handler<'env> =>
  async ctx =>
    try await handler(ctx) catch {
    | exn => rethrowAsError(exn)
    }

let get = (router, path, handler) => router->honoGet(path, catchExceptions(handler))
let post = (router, path, handler) => router->honoPost(path, catchExceptions(handler))
let all = (router, path, handler) => router->honoAll(path, catchExceptions(handler))
let notFound = (router, handler) => router->honoNotFound(catchExceptions(handler))

let use = (router, ~path=?, middleware: middleware<'env>) => {
  let wrapped = async (ctx, next) =>
    try await middleware(ctx, next) catch {
    | exn => rethrowAsError(exn)
    }
  switch path {
  | None => router->honoUse(wrapped)
  | Some(path) => router->honoUseAt(path, wrapped)
  }
}

let register = (router, route: EndpointHandler.route<'env>) =>
  switch route.method {
  | Get => router->honoGet(route.path, route.run)
  | Post => router->honoPost(route.path, route.run)
  }

let assertRegistered = (router, endpoints: array<Endpoint.any>) => {
  let routes = router->routes
  let missing =
    endpoints->Array.filter(endpoint =>
      !(
        routes->Array.some(route =>
          route.path == endpoint.path && route.method == Endpoint.methodName(endpoint.method)
        )
      )
    )
  if missing != [] {
    let names = missing->Array.map(e => `${Endpoint.methodName(e.method)} ${e.path}`)
    JsError.throwWithMessage(`Endpoints without a route: ${names->Array.join(", ")}`)
  }
}
