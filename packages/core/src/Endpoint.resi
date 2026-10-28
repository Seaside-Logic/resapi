// A contract describes an endpoint's wire format and is safe to share with clients: it references no
// server or runtime code. Server adapters turn contracts into routes.

type method = Get | Post | Put

/** The error type of an endpoint that declares no application errors. It has no values, so a handler
    for such an endpoint cannot return `Error(_)`. */
type noError

/** Read-only outside this module: contracts are built with `get`/`post`/`put`, which check the route. */
type t<'params, 'body, 'response, 'error> = private {
  method: method,
  path: string,
  paramsCodec: Codec.t<'params>,
  bodyCodec: Codec.t<'body>,
  responseCodec: Codec.t<'response>,
  errorCodec: Codec.t<'error>,
  errorStatus: 'error => int,
}

/** Throws if the route's `:params` don't match the params codec (see `RouteCheck`). Define contracts
    at module top level, so a mismatch fails at load. */
let get: (string, ~params: Codec.t<'p>, ~response: Codec.t<'r>) => t<'p, unit, 'r, noError>

/** Throws if the route's `:params` don't match the params codec (see `RouteCheck`). */
let post: (
  string,
  ~params: Codec.t<'p>,
  ~body: Codec.t<'b>,
  ~response: Codec.t<'r>,
) => t<'p, 'b, 'r, noError>

/** Throws if the route's `:params` don't match the params codec (see `RouteCheck`). */
let put: (
  string,
  ~params: Codec.t<'p>,
  ~body: Codec.t<'b>,
  ~response: Codec.t<'r>,
) => t<'p, 'b, 'r, noError>

/** Declares the endpoint's application errors and the HTTP status (4xx or 5xx) each one is sent with. */
let withErrors: (t<'p, 'b, 'r, noError>, Codec.t<'e>, ~status: 'e => int) => t<'p, 'b, 'r, 'e>

/** A contract with its types erased: just the route. Lets contracts of different types share a list,
    e.g. for an adapter's `assertRegistered`. */
type any = private {method: method, path: string}

let any: t<'p, 'b, 'r, 'e> => any

/** `"GET"`, `"POST"`, or `"PUT"`. */
let methodName: method => string
