// A contract describes an endpoint's wire format and is safe to share with clients:
// it references no server or runtime code. Server adapters turn contracts into routes.
// Constructors check the route's params against the params codec and throw on a mismatch (RouteCheck).

type method = Get | Post | Put

type noError

type t<'params, 'body, 'response, 'error> = {
  method: method,
  path: string,
  paramsCodec: Codec.t<'params>,
  bodyCodec: Codec.t<'body>,
  responseCodec: Codec.t<'response>,
  errorCodec: Codec.t<'error>,
  errorStatus: 'error => int,
}

// Never encodes (no value exists) and never decodes: an error body for such an endpoint is a protocol error.
let noErrorCodec: Codec.t<noError> = {
  decode: _ => Error({path: [], message: "This endpoint declares no application errors"}),
  encode: _ => JSON.Null,
}

let get = (path, ~params, ~response) => {
  RouteCheck.assertValid(path, params)
  {
    method: Get,
    path,
    paramsCodec: params,
    bodyCodec: Codec.unit,
    responseCodec: response,
    errorCodec: noErrorCodec,
    errorStatus: _ => 500,
  }
}

let post = (path, ~params, ~body, ~response) => {
  RouteCheck.assertValid(path, params)
  {
    method: Post,
    path,
    paramsCodec: params,
    bodyCodec: body,
    responseCodec: response,
    errorCodec: noErrorCodec,
    errorStatus: _ => 500,
  }
}

let put = (path, ~params, ~body, ~response) => {
  RouteCheck.assertValid(path, params)
  {
    method: Put,
    path,
    paramsCodec: params,
    bodyCodec: body,
    responseCodec: response,
    errorCodec: noErrorCodec,
    errorStatus: _ => 500,
  }
}

let withErrors = (contract: t<'p, 'b, 'r, noError>, errorCodec: Codec.t<'e>, ~status) => {
  ...contract,
  errorCodec,
  errorStatus: status,
}

type any = {method: method, path: string}

let any = (contract: t<_, _, _, _>) => {method: contract.method, path: contract.path}

let methodName = method =>
  switch method {
  | Get => "GET"
  | Post => "POST"
  | Put => "PUT"
  }
