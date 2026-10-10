// Turns a contract into a route: decodes the request, runs the typed handler and encodes its result.
// The handler's types are closed over, so routes of any contract types share one type.
open ResApi

type input<'params, 'body> = {params: 'params, body: 'body}

/** `Error(e)` must be one of the contract's declared application errors (see `Endpoint.withErrors`). */
type handler<'env, 'params, 'body, 'response, 'error> = (
  Context.t<'env>,
  input<'params, 'body>,
) => promise<result<'response, 'error>>

type route<'env> = {
  method: Endpoint.method,
  path: string,
  run: Context.t<'env> => promise<Fetch.Response.t>,
}

let errorResponse = (~status, ~kind, ~message, ~path=[]) =>
  Fetch.Response.json(
    JSON.Encode.object(
      dict{
        "error": JSON.Encode.object(
          dict{
            "kind": JSON.Encode.string(kind),
            "message": JSON.Encode.string(message),
            "path": JSON.Encode.array(path->Array.map(JSON.Encode.string)),
          },
        ),
      },
    ),
    ~init={status: status},
  )

// Declared errors travel as `{"applicationError": <encoded>}`, apart from the framework's `{"error": ...}`.
let applicationErrorResponse = (contract: Endpoint.t<_, _, _, _>, error) => {
  let status = contract.errorStatus(error)
  if status < 400 || status > 599 {
    JsError.throwWithMessage(`Application error status must be 4xx or 5xx, got ${status->Int.toString}`)
  }
  Fetch.Response.json(
    JSON.Encode.object(dict{"applicationError": contract.errorCodec.encode(error)}),
    ~init={status: status},
  )
}

let readJsonBody = async (contract: Endpoint.t<_, _, _, _>, ctx) =>
  switch contract.method {
  | Get => Ok(JSON.Null)
  | Post =>
    try Ok(JSON.parseOrThrow(await ctx->Context.text)) catch {
    | JsExn(e) => Error(e->JsExn.message->Option.getOr("Invalid JSON"))
    }
  }

// Params are decoded before the body is read, so a bad URL never costs a body parse.
let respond = async (contract: Endpoint.t<_, _, _, _>, handler, ctx) => {
  let rawParams = JSON.Object(ctx->Context.params->Dict.mapValues(s => JSON.String(s)))
  switch contract.paramsCodec.decode(rawParams) {
  | Error({path, message}) => errorResponse(~status=400, ~kind="invalid_params", ~message, ~path)
  | Ok(params) =>
    switch await readJsonBody(contract, ctx) {
    | Error(message) => errorResponse(~status=400, ~kind="malformed_json", ~message)
    | Ok(json) =>
      switch contract.bodyCodec.decode(json) {
      | Error({path, message}) => errorResponse(~status=400, ~kind="invalid_body", ~message, ~path)
      | Ok(body) =>
        switch await handler(ctx, {params, body}) {
        | Ok(response) => Fetch.Response.json(contract.responseCodec.encode(response))
        | Error(error) => applicationErrorResponse(contract, error)
        }
      }
    }
  }
}

/** Any exception from a codec or the handler is logged and answered with a 500 that reveals nothing. */
let make = (contract: Endpoint.t<_, _, _, _>, handler: handler<_, _, _, _, _>) => {
  method: contract.method,
  path: contract.path,
  run: async ctx =>
    try await respond(contract, handler, ctx) catch {
    | exn =>
      // Log the JS Error itself, not ReScript's wrapper, so the stack trace shows.
      switch exn {
      | JsExn(e) => Console.error(e)
      | exn => Console.error(exn)
      }
      errorResponse(~status=500, ~kind="internal", ~message="Internal Server Error")
    },
}
