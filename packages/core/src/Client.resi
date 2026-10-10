// Calls an endpoint contract over HTTP. Depends only on contracts and Fetch, never on a server adapter.

type t

type error<'e> =
  | Application({status: int, error: 'e})
  | Network(string)
  | Aborted
  | UnexpectedStatus({status: int, body: string})
  | InvalidResponse(Codec.error)
  | InvalidParams(string)
  | EncodeFailed(string)

/** `~fetch` defaults to the global fetch; pass another to call in-process or to fake a server.
    `~baseUrl` keeps its path prefix: `https://x.dev/api/` + `/a` is `https://x.dev/api/a`.
    `~headers` are sent with every request. */
let make: (
  ~baseUrl: string,
  ~fetch: Fetch.Request.t => promise<Fetch.Response.t>=?,
  ~headers: dict<string>=?,
) => t

/** For contracts without a request body (`'body = unit`).

    `~headers` override the client's headers and resAPI's `content-type`; names are case-insensitive.
    Aborting `~signal` (or its timeout firing) ends the call with `Error(Aborted)`. */
let call: (
  t,
  Endpoint.t<'p, unit, 'r, 'e>,
  ~params: 'p,
  ~headers: dict<string>=?,
  ~signal: Fetch.AbortSignal.t=?,
) => promise<result<'r, error<'e>>>

/** For contracts with a request body. `~headers` and `~signal` work as in `call`. */
let callWithBody: (
  t,
  Endpoint.t<'p, 'b, 'r, 'e>,
  ~params: 'p,
  ~body: 'b,
  ~headers: dict<string>=?,
  ~signal: Fetch.AbortSignal.t=?,
) => promise<result<'r, error<'e>>>
