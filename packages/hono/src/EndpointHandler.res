// Turns a contract into a route: decodes the request, runs the typed handler and encodes its result.
// The handler's types are closed over, so routes of any contract types share one type.
open ResApi

type failure = {status: int, message: string}
type input<'params, 'body> = {params: 'params, body: 'body}
type handler<'env, 'params, 'body, 'response> = (
  Context.t<'env>,
  input<'params, 'body>,
) => promise<result<'response, failure>>

type route<'env> = {
  method: Endpoint.method,
  path: string,
  run: Context.t<'env> => promise<Fetch.Response.t>,
}

let notFound = message => {status: 404, message}

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

let readJsonBody = async (contract: Endpoint.t<_, _, _>, ctx) =>
  switch contract.method {
  | Get => Ok(JSON.Null)
  | Post =>
    try Ok(JSON.parseOrThrow(await ctx->Context.text)) catch {
    | JsExn(e) => Error(e->JsExn.message->Option.getOr("Invalid JSON"))
    }
  }

// Params are decoded before the body is read, so a bad URL never costs a body parse.
let respond = async (contract: Endpoint.t<_, _, _>, handler, ctx) => {
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
        | Error({status, message}) => errorResponse(~status, ~kind="application", ~message)
        }
      }
    }
  }
}

/** Any exception from a codec or the handler is logged and answered with a 500 that reveals nothing. */
let make = (contract: Endpoint.t<_, _, _>, handler: handler<_, _, _, _>) => {
  method: contract.method,
  path: contract.path,
  run: async ctx =>
    try await respond(contract, handler, ctx) catch {
    | exn =>
      Console.error(exn)
      errorResponse(~status=500, ~kind="internal", ~message="Internal Server Error")
    },
}
