// Turns a contract into a route: the request runs through core's Dispatch pipeline, and the result is
// sent as a Fetch Response.

type input<'params, 'body> = ResApi.Dispatch.input<'params, 'body> = {params: 'params, body: 'body}

/** `Error(e)` must be one of the contract's declared application errors (see `Endpoint.withErrors`). */
type handler<'env, 'params, 'body, 'response, 'error> = (
  Context.t<'env>,
  input<'params, 'body>,
) => promise<result<'response, 'error>>

/** Mount with `Router.register`. */
type route<'env> = private {
  method: ResApi.Endpoint.method,
  path: string,
  run: Context.t<'env> => promise<ResApi.Fetch.Response.t>,
}

/** Invalid input is a 400, and any exception from a codec or the handler is logged and answered with a
    500 that reveals nothing. */
let make: (
  ResApi.Endpoint.t<'params, 'body, 'response, 'error>,
  handler<'env, 'params, 'body, 'response, 'error>,
) => route<'env>
