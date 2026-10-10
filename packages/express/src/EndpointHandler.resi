// Turns a contract into a route: the request runs through core's Dispatch pipeline, and the result is
// sent with `res.status().json()`.

type input<'params, 'body> = ResApi.Dispatch.input<'params, 'body> = {params: 'params, body: 'body}

/** `Error(e)` must be one of the contract's declared application errors (see `Endpoint.withErrors`). */
type handler<'params, 'body, 'response, 'error> = (
  Req.t,
  input<'params, 'body>,
) => promise<result<'response, 'error>>

/** Mount with `Router.register`. */
type route = private {
  method: ResApi.Endpoint.method,
  path: string,
  run: (Req.t, Res.t) => promise<unit>,
}

/** Invalid input is a 400, and any exception from a codec or the handler is logged and answered with a
    500 that reveals nothing. */
let make: (
  ResApi.Endpoint.t<'params, 'body, 'response, 'error>,
  handler<'params, 'body, 'response, 'error>,
) => route
