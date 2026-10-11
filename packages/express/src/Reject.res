// Auth rejections in resAPI's error shape, for middleware. See Reject.resi.
let send = (res, ~status, ~kind, ~reason) => {
  let {status, body} = ResApi.Dispatch.errorResponse(
    ~status,
    ~kind,
    ~message=reason->Option.getOr(""),
  )
  res->Res.status(status)->Res.json(body)
}

let unauthenticated = (res, ~reason=?) => res->send(~status=401, ~kind="unauthenticated", ~reason)
let forbidden = (res, ~reason=?) => res->send(~status=403, ~kind="forbidden", ~reason)
