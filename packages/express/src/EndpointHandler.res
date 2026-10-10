// Turns a contract into a route: the request runs through core's Dispatch pipeline, and the result is
// sent with `res.status().json()`. The handler's types are closed over, so routes of any contract types share one type.
open ResApi

type input<'params, 'body> = Dispatch.input<'params, 'body> = {params: 'params, body: 'body}

/** `Error(e)` must be one of the contract's declared application errors (see `Endpoint.withErrors`). */
type handler<'params, 'body, 'response, 'error> = (
  Req.t,
  input<'params, 'body>,
) => promise<result<'response, 'error>>

type route = {
  method: Endpoint.method,
  path: string,
  run: (Req.t, Res.t) => promise<unit>,
}

// Router.register mounts POST routes behind `express.text`, so the body is the raw string. A body
// already parsed by an upstream `express.json()` is used as it is. No body at all parses as "".
let rawBody = req =>
  switch req->Req.body->Nullable.toOption {
  | None => Dispatch.Text(Promise.resolve(""))
  | Some(JSON.String(text)) => Text(Promise.resolve(text))
  | Some(json) => Parsed(json)
  }

/** Invalid input is a 400, and any exception from a codec or the handler is logged and answered with a
    500 that reveals nothing (see `Dispatch.run`). */
let make = (contract: Endpoint.t<_, _, _, _>, handler: handler<_, _, _, _>) => {
  method: contract.method,
  path: contract.path,
  run: async (req, res) => {
    let {status, body} = await Dispatch.run(
      contract,
      ~params=req->Req.params,
      ~readBody=() => rawBody(req),
      ~handle=input => handler(req, input),
    )
    res->Res.status(status)->Res.json(body)
  },
}
