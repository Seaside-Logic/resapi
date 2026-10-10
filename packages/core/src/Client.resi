// Calls an endpoint contract over HTTP. Depends only on contracts and Fetch, never on a server adapter.

type t

type error<'e> =
  | Application({status: int, error: 'e})
  | Network(string)
  | UnexpectedStatus({status: int, body: string})
  | InvalidResponse(Codec.error)
  | InvalidParams(string)
  | EncodeFailed(string)

/** `~fetch` defaults to the global fetch; pass another to call in-process or to fake a server.
    `~baseUrl` keeps its path prefix: `https://x.dev/api/` + `/a` is `https://x.dev/api/a`. */
let make: (~baseUrl: string, ~fetch: Fetch.Request.t => promise<Fetch.Response.t>=?) => t

/** For contracts without a request body (`'body = unit`). */
let call: (t, Endpoint.t<'p, unit, 'r, 'e>, ~params: 'p) => promise<result<'r, error<'e>>>

/** For contracts with a request body. */
let callWithBody: (
  t,
  Endpoint.t<'p, 'b, 'r, 'e>,
  ~params: 'p,
  ~body: 'b,
) => promise<result<'r, error<'e>>>
