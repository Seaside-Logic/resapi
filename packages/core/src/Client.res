// Calls an endpoint contract over HTTP. Depends only on contracts and Fetch, never on a server adapter.

type t = {baseUrl: string, fetch: Fetch.Request.t => promise<Fetch.Response.t>}

type error<'e> =
  | Application({status: int, error: 'e})
  | Network(string)
  | UnexpectedStatus({status: int, body: string})
  | InvalidResponse(Codec.error)
  | InvalidParams(string)
  | EncodeFailed(string)

@val external globalFetch: Fetch.Request.t => promise<Fetch.Response.t> = "fetch"
@val external encodeURIComponent: string => string = "encodeURIComponent"

/** `~fetch` defaults to the global fetch; pass another to call in-process or to fake a server. */
let make = (~baseUrl, ~fetch=globalFetch) => {baseUrl, fetch}

/** Appends the path to the base URL, keeping any path prefix in the base: `https://x.dev/api/` + `/a` is `https://x.dev/api/a`. */
let joinUrl = (baseUrl, path) => {
  let base = baseUrl->String.endsWith("/") ? baseUrl->String.slice(~start=0, ~end=-1) : baseUrl
  path->String.startsWith("/") ? base ++ path : `${base}/${path}`
}

let paramValue = (values, name) =>
  switch values->Dict.get(name) {
  | Some(JSON.String(s)) => Ok(s)
  | Some(Number(n)) => Ok(n->Float.toString)
  | Some(Boolean(b)) => Ok(b ? "true" : "false")
  | Some(_) => Error(InvalidParams(`Path parameter "${name}" must be a string, number or boolean`))
  | None => Error(InvalidParams(`Missing path parameter "${name}"`))
  }

/** Fills `:name` segments from the encoded params object, percent-encoding each value. */
let buildPath = (path, params: JSON.t) => {
  let values = switch params {
  | Object(values) => values
  | _ => dict{}
  }
  path
  ->String.split("/")
  ->Array.reduce(Ok([]), (acc, segment) =>
    acc->Result.flatMap(segments =>
      segment->String.startsWith(":")
        ? paramValue(values, segment->String.slice(~start=1))->Result.map(
            value => [...segments, encodeURIComponent(value)],
          )
        : Ok([...segments, segment])
    )
  )
  ->Result.map(segments => segments->Array.join("/"))
}

let encodeWith = (encode, value) =>
  try Ok(encode(value)) catch {
  | JsExn(e) => Error(EncodeFailed(e->JsExn.message->Option.getOr("Encoding failed")))
  | _ => Error(EncodeFailed("Encoding failed"))
  }

let parseJson = text =>
  try Ok(JSON.parseOrThrow(text)) catch {
  | JsExn(e) => Error({Codec.path: [], message: e->JsExn.message->Option.getOr("Invalid JSON")})
  }

let decodeResponse = (contract: Endpoint.t<_, _, _, _>, text) =>
  parseJson(text)
  ->Result.flatMap(contract.responseCodec.decode)
  ->Result.mapError(e => InvalidResponse(e))

// A non-2xx body of `{"applicationError": ...}` is a declared error and must decode as one; anything
// else (framework errors, proxies, plain text) is just an unexpected status.
let decodeFailure = (contract: Endpoint.t<_, _, _, _>, status, text) =>
  switch parseJson(text) {
  | Ok(Object(body)) =>
    switch body->Dict.get("applicationError") {
    | Some(json) =>
      switch contract.errorCodec.decode(json) {
      | Ok(error) => Error(Application({status, error}))
      | Error(e) => Error(InvalidResponse({...e, path: ["applicationError", ...e.path]}))
      }
    | None => Error(UnexpectedStatus({status, body: text}))
    }
  | _ => Error(UnexpectedStatus({status, body: text}))
  }

// Only the transport is inside the try: codec and status errors are classified elsewhere.
let fetchText = async (client, request) =>
  try {
    let response = await client.fetch(request)
    Ok((response, await response->Fetch.Response.readText))
  } catch {
  | JsExn(e) => Error(Network(e->JsExn.message->Option.getOr("fetch failed")))
  }

let requestInit = (contract: Endpoint.t<_, _, _, _>, body): result<Fetch.Request.init, _> =>
  switch contract.method {
  | Get => Ok({method: "GET"})
  | Post =>
    encodeWith(contract.bodyCodec.encode, body)->Result.map((json): Fetch.Request.init => {
      method: "POST",
      headers: dict{"content-type": "application/json"},
      body: json->JSON.stringify,
    })
  }

let send = async (client, contract: Endpoint.t<_, _, _, _>, ~params, ~body) => {
  let prepared =
    encodeWith(contract.paramsCodec.encode, params)
    ->Result.flatMap(json => buildPath(contract.path, json))
    ->Result.flatMap(path => requestInit(contract, body)->Result.map(init => (path, init)))
  switch prepared {
  | Error(e) => Error(e)
  | Ok((path, init)) =>
    // An invalid baseUrl makes Request throw: a configuration bug, not a request failure.
    switch await fetchText(client, Fetch.Request.make(joinUrl(client.baseUrl, path), ~init)) {
    | Error(e) => Error(e)
    | Ok((response, text)) =>
      response->Fetch.Response.ok
        ? decodeResponse(contract, text)
        : decodeFailure(contract, response->Fetch.Response.status, text)
    }
  }
}

/** For contracts without a request body (`'body = unit`). */
let call = (client, contract, ~params) => send(client, contract, ~params, ~body=())

let callWithBody = send
