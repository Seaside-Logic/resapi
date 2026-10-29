// Calls an endpoint contract over HTTP. Depends only on contracts and Fetch, never on a server adapter.

type t = {
  baseUrl: string,
  fetch: Fetch.Request.t => promise<Fetch.Response.t>,
  headers: dict<string>,
}

type error<'e> =
  | Application({status: int, error: 'e})
  | Unauthorized({status: int, reason: option<string>})
  | Network(string)
  | Aborted
  | UnexpectedStatus({status: int, body: string})
  | InvalidResponse(Codec.error)

@val external encodeURIComponent: string => string = "encodeURIComponent"

let make = (~baseUrl, ~fetch=request => Fetch.fetchWithRequest(request), ~headers=dict{}) => {
  baseUrl,
  fetch,
  headers,
}

/** Appends the path to the base URL, keeping any path prefix in the base: `https://x.dev/api/` + `/a` is `https://x.dev/api/a`. */
let joinUrl = (baseUrl, path) => {
  let base = baseUrl->String.endsWith("/") ? baseUrl->String.slice(~start=0, ~end=-1) : baseUrl
  path->String.startsWith("/") ? base ++ path : `${base}/${path}`
}

// Programmer errors throw: a param that can't fill the path, or a codec that throws. They're bugs in the
// calling code, and nothing has been sent (like an invalid baseUrl, which makes Request throw).
let paramValue = (values, name) =>
  switch values->Dict.get(name) {
  | Some(JSON.String(s)) => s
  | Some(Number(n)) => n->Float.toString
  | Some(Boolean(b)) => b ? "true" : "false"
  | Some(_) =>
    JsError.throwWithMessage(`Path parameter "${name}" must be a string, number or boolean`)
  | None => JsError.throwWithMessage(`Missing path parameter "${name}"`)
  }

/** Fills `:name` segments from the encoded params object, percent-encoding each value. */
let buildPath = (path, params: JSON.t) => {
  let values = switch params {
  | Object(values) => values
  | _ => dict{}
  }
  path
  ->String.split("/")
  ->Array.map(segment =>
    segment->String.startsWith(":")
      ? encodeURIComponent(paramValue(values, segment->String.slice(~start=1)))
      : segment
  )
  ->Array.join("/")
}

// A ReScript exception, or a JS throw of something other than an Error, becomes a JS Error, so the
// rejected call always carries a message and a stack.
let encodeOrThrow = (encode, value) =>
  try encode(value) catch {
  | JsExn(e) if e->JsExn.message->Option.isSome => JsExn.throw(e)
  | _ => JsError.throwWithMessage("Encoding failed")
  }

let parseJson = text =>
  try Ok(JSON.parseOrThrow(text)) catch {
  | JsExn(e) => Error({Codec.path: [], message: e->JsExn.message->Option.getOr("Invalid JSON")})
  }

let decodeResponse = (contract: Endpoint.t<_, _, _, _>, text) =>
  parseJson(text)
  ->Result.flatMap(contract.responseCodec.decode)
  ->Result.mapError(e => InvalidResponse(e))

// The reason a resAPI rejection (the adapters' `Reject`) carries, when this body is one.
let rejectionReason = json =>
  switch json {
  | Ok(JSON.Object(dict{
      "error": JSON.Object(dict{
        "kind": JSON.String("unauthenticated" | "forbidden"),
        "message": JSON.String(message),
      }),
    })) if message != "" =>
    Some(message)
  | _ => None
  }

// A declared error (`{"applicationError": ...}`) wins at any status and must decode as one. Otherwise
// 401 and 403 are Unauthorized, from resAPI's Reject or any other middleware; the rest is unexpected.
let decodeFailure = (contract: Endpoint.t<_, _, _, _>, status, text) => {
  let json = parseJson(text)
  let declared = switch json {
  | Ok(Object(body)) => body->Dict.get("applicationError")
  | _ => None
  }
  switch declared {
  | Some(error) =>
    switch contract.errorCodec.decode(error) {
    | Ok(error) => Error(Application({status, error}))
    | Error(e) => Error(InvalidResponse({...e, path: ["applicationError", ...e.path]}))
    }
  | None if status == 401 || status == 403 =>
    Error(Unauthorized({status, reason: rejectionReason(json)}))
  | None => Error(UnexpectedStatus({status, body: text}))
  }
}

// Only the transport is inside the try: codec and status errors are classified elsewhere.
let fetchText = async (client, request) =>
  try {
    let response = await client.fetch(request)
    Ok((response, await response->Fetch.Response.text))
  } catch {
  | JsExn(e) =>
    switch e->JsExn.name {
    | Some("AbortError" | "TimeoutError") => Error(Aborted)
    | _ => Error(Network(e->JsExn.message->Option.getOr("fetch failed")))
    }
  }

// Later sources win. Names are lowercased, because Fetch would otherwise combine `Authorization` and
// `authorization` into one comma-separated value instead of overriding.
let mergeHeaders = sources => {
  let merged = dict{}
  sources->Array.forEach(source =>
    source->Dict.forEachWithKey((value, name) => merged->Dict.set(name->String.toLowerCase, value))
  )
  merged
}

let requestInit = (
  client,
  contract: Endpoint.t<_, _, _, _>,
  body,
  ~headers,
  ~signal,
): Fetch.Request.requestInit => {
  let signal = signal->Option.map(Nullable.make)
  switch contract.method {
  | Get => {
      method: "GET",
      headers: Fetch.HeadersInit.fromDict(mergeHeaders([client.headers, headers])),
      ?signal,
    }
  | Post | Put => {
      method: Endpoint.methodName(contract.method),
      headers: Fetch.HeadersInit.fromDict(
        mergeHeaders([client.headers, dict{"content-type": "application/json"}, headers]),
      ),
      body: Nullable.make(
        Fetch.BodyInit.fromString(encodeOrThrow(contract.bodyCodec.encode, body)->JSON.stringify),
      ),
      ?signal,
    }
  }
}

let send = async (
  client,
  contract: Endpoint.t<_, _, _, _>,
  ~params,
  ~body,
  ~headers=dict{},
  ~signal=?,
) => {
  let path = buildPath(contract.path, encodeOrThrow(contract.paramsCodec.encode, params))
  let init = requestInit(client, contract, body, ~headers, ~signal)
  switch await fetchText(client, Fetch.Request.fromURL(joinUrl(client.baseUrl, path), ~init)) {
  | Error(e) => Error(e)
  | Ok((response, text)) =>
    response.ok ? decodeResponse(contract, text) : decodeFailure(contract, response.status, text)
  }
}

let call = (client, contract, ~params, ~headers=?, ~signal=?) =>
  send(client, contract, ~params, ~body=(), ~headers?, ~signal?)

let callWithBody = send

let message = (error, ~declared) =>
  switch error {
  | Application({error, _}) => declared(error)
  | Unauthorized({status: 401, _}) => "Please sign in."
  | Unauthorized(_) => "You don't have permission to do that."
  | Network(_) => "Can't reach the server. Check your connection and try again."
  | Aborted => "The request was cancelled."
  | UnexpectedStatus(_) | InvalidResponse(_) => "Something went wrong. Please try again."
  }
