// The adapter-neutral server pipeline: decodes a request, runs a typed handler and encodes its result
// in resAPI's wire format. Server adapters supply the raw params and body and send the result.
// No server or runtime code here.

type input<'params, 'body> = {params: 'params, body: 'body}

type response = {status: int, body: JSON.t}

/** The request body, as the adapter has it. `Parsed` is JSON already parsed by framework middleware. */
type rawBody = Text(promise<string>) | Parsed(JSON.t)

let errorResponse = (~status, ~kind, ~message, ~path=[]) => {
  status,
  body: JSON.Encode.object(
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
}

// Declared errors travel as `{"applicationError": <encoded>}`, apart from the framework's `{"error": ...}`.
let applicationErrorResponse = (contract: Endpoint.t<_, _, _, _>, error) => {
  let status = contract.errorStatus(error)
  if status < 400 || status > 599 {
    JsError.throwWithMessage(
      `Application error status must be 4xx or 5xx, got ${status->Int.toString}`,
    )
  }
  {status, body: JSON.Encode.object(dict{"applicationError": contract.errorCodec.encode(error)})}
}

let readJsonBody = async (contract: Endpoint.t<_, _, _, _>, readBody) =>
  switch contract.method {
  | Get => Ok(JSON.Null)
  | Post =>
    switch readBody() {
    | Parsed(json) => Ok(json)
    | Text(text) =>
      try Ok(JSON.parseOrThrow(await text)) catch {
      | JsExn(e) => Error(e->JsExn.message->Option.getOr("Invalid JSON"))
      }
    }
  }

// Params are decoded before the body is read, so a bad URL never costs a body parse.
let respond = async (contract: Endpoint.t<_, _, _, _>, ~params, ~readBody, ~handle) => {
  let rawParams = JSON.Object(params->Dict.mapValues(s => JSON.String(s)))
  switch contract.paramsCodec.decode(rawParams) {
  | Error({path, message}) => errorResponse(~status=400, ~kind="invalid_params", ~message, ~path)
  | Ok(params) =>
    switch await readJsonBody(contract, readBody) {
    | Error(message) => errorResponse(~status=400, ~kind="malformed_json", ~message)
    | Ok(json) =>
      switch contract.bodyCodec.decode(json) {
      | Error({path, message}) => errorResponse(~status=400, ~kind="invalid_body", ~message, ~path)
      | Ok(body) =>
        switch await handle({params, body}) {
        | Ok(response) => {status: 200, body: contract.responseCodec.encode(response)}
        | Error(error) => applicationErrorResponse(contract, error)
        }
      }
    }
  }
}

/** `readBody` is called only for POST, after params decode. `handle` must return one of the contract's
    declared errors. Any exception from a codec or `handle` is logged and answered with a 500 that
    reveals nothing. */
let run = async (
  contract: Endpoint.t<'params, 'body, 'response, 'error>,
  ~params: dict<string>,
  ~readBody: unit => rawBody,
  ~handle: input<'params, 'body> => promise<result<'response, 'error>>,
) =>
  try await respond(contract, ~params, ~readBody, ~handle) catch {
  | exn =>
    // Log the JS Error itself, not ReScript's wrapper, so the stack trace shows.
    switch exn {
    | JsExn(e) => Console.error(e)
    | exn => Console.error(exn)
    }
    errorResponse(~status=500, ~kind="internal", ~message="Internal Server Error")
  }
