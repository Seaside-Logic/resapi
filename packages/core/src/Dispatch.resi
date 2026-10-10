// The adapter-neutral server pipeline shared by the first-party adapters (@resapi/hono, @resapi/express).
// Unstable: this is not an extension API for third-party adapters yet, and it may change in any release.

type input<'params, 'body> = {params: 'params, body: 'body}

type response = {status: int, body: JSON.t}

/** The request body, as the adapter has it. `Parsed` is JSON already parsed by framework middleware. */
type rawBody = Text(promise<string>) | Parsed(JSON.t)

/** `readBody` is called only for POST, after params decode. `handle` must return one of the contract's
    declared errors. Any exception from a codec, `handle` or reading the body is logged and answered
    with a 500 that reveals nothing. */
let run: (
  Endpoint.t<'params, 'body, 'response, 'error>,
  ~params: dict<string>,
  ~readBody: unit => rawBody,
  ~handle: input<'params, 'body> => promise<result<'response, 'error>>,
) => promise<response>
