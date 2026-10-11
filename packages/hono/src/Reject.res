// Auth rejections in resAPI's error shape, for middleware. See Reject.resi.
let respond = (~status, ~kind, ~reason) => {
  let {status, body} = ResApi.Dispatch.errorResponse(
    ~status,
    ~kind,
    ~message=reason->Option.getOr(""),
  )
  ResApi.Fetch.Response.jsonR(~data=body, ~init={status: status})
}

let unauthenticated = (~reason=?) => respond(~status=401, ~kind="unauthenticated", ~reason)
let forbidden = (~reason=?) => respond(~status=403, ~kind="forbidden", ~reason)
