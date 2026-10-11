// Contracts with hand-written codecs, shared by runtime tests and compile-fail cases. Core only.
open ResApi

type params = {id: string}
type account = {id: string, name: string}
type newAccount = {name: string}
type memberParams = {org: string, member: int}
type accountError = NotFound | AccessDenied

let field = (json: JSON.t, key): result<string, Codec.error> =>
  switch json {
  | Object(d) =>
    switch d->Dict.get(key) {
    | Some(String(s)) => Ok(s)
    | _ => Error({path: [key], message: "Expected string"})
    }
  | _ => Error({path: [], message: "Expected object"})
  }

let paramsCodec: Codec.t<params> = {
  decode: json => field(json, "id")->Result.map(id => {id: id}),
  encode: p => JSON.Object(dict{"id": JSON.String(p.id)}),
}

let accountCodec: Codec.t<account> = {
  decode: json =>
    switch (field(json, "id"), field(json, "name")) {
    | (Ok(id), Ok(name)) => Ok({id, name})
    | (Error(e), _) | (_, Error(e)) => Error(e)
    },
  encode: a => JSON.Object(dict{"id": JSON.String(a.id), "name": JSON.String(a.name)}),
}

let newAccountCodec: Codec.t<newAccount> = {
  decode: json => field(json, "name")->Result.map(name => {name: name}),
  encode: a => JSON.Object(dict{"name": JSON.String(a.name)}),
}

// Route params arrive as strings; `member` must parse as an int.
let memberParamsCodec: Codec.t<memberParams> = {
  decode: json =>
    switch (field(json, "org"), field(json, "member")) {
    | (Ok(org), Ok(member)) =>
      switch Int.fromString(member) {
      | Some(member) => Ok({org, member})
      | None => Error({path: ["member"], message: "Expected integer"})
      }
    | (Error(e), _) | (_, Error(e)) => Error(e)
    },
  encode: p => JSON.Object(
    dict{"org": JSON.String(p.org), "member": JSON.Number(p.member->Int.toFloat)},
  ),
}

let accountErrorCodec: Codec.t<accountError> = {
  decode: json =>
    switch json {
    | String("not_found") => Ok(NotFound)
    | String("access_denied") => Ok(AccessDenied)
    | _ => Error({path: [], message: "Expected an account error"})
    },
  encode: error =>
    switch error {
    | NotFound => JSON.String("not_found")
    | AccessDenied => JSON.String("access_denied")
    },
}

let getAccount = Endpoint.get(
  "/accounts/:id",
  ~params=paramsCodec,
  ~response=accountCodec,
)->Endpoint.withErrors(accountErrorCodec, ~status=error =>
  switch error {
  | NotFound => 404
  | AccessDenied => 403
  }
)

// Declares a 200 for its error: the server must refuse to send that as an application error.
let badErrorStatus =
  Endpoint.get(
    "/bad-error-status",
    ~params=Codec.unit,
    ~response=accountCodec,
  )->Endpoint.withErrors(accountErrorCodec, ~status=_ => 200)

let createAccount = Endpoint.post(
  "/accounts",
  ~params=Codec.unit,
  ~body=newAccountCodec,
  ~response=accountCodec,
)

let getMember = Endpoint.get(
  "/orgs/:org/members/:member",
  ~params=memberParamsCodec,
  ~response=accountCodec,
)

let addMember = Endpoint.post(
  "/orgs/:org/members/:member",
  ~params=memberParamsCodec,
  ~body=newAccountCodec,
  ~response=accountCodec,
)

// Its response encoder throws, for the server's internal-error path.
let brokenEncoder = Endpoint.get(
  "/broken",
  ~params=Codec.unit,
  ~response={...accountCodec, encode: _ => JsError.throwWithMessage("secret internal detail")},
)

// Broken params codecs, for the client's error classification. Their decoder rejects the probe value at
// `id` as a refined codec would, so RouteCheck can't validate them (CannotValidate) and the client's
// own checks are the only guard.
let encodeOnly = (encode): Codec.t<string> => {
  decode: _ => Error({path: ["id"], message: "Expected a real id"}),
  encode,
}

let missingParam = Endpoint.get(
  "/accounts/:id",
  ~params=encodeOnly(_ => JSON.Object(dict{})),
  ~response=accountCodec,
)

let nonScalarParam = Endpoint.get(
  "/accounts/:id",
  ~params=encodeOnly(id => JSON.Object(dict{"id": JSON.Array([JSON.String(id)])})),
  ~response=accountCodec,
)

let throwingParams = Endpoint.get(
  "/accounts/:id",
  ~params=encodeOnly(_ => JsError.throwWithMessage("cannot encode")),
  ~response=accountCodec,
)

// Throws a ReScript exception (not a JS Error) while encoding: the call must still reject with an Error.
let rescriptThrowingParams = Endpoint.get(
  "/accounts/:id",
  ~params=encodeOnly(_ => throw(Not_found)),
  ~response=accountCodec,
)

// Its body decoder throws, for the server's internal-error path.
let throwingBody = Endpoint.post(
  "/throwing-body",
  ~params=Codec.unit,
  ~body={...newAccountCodec, decode: _ => JsError.throwWithMessage("secret internal detail")},
  ~response=accountCodec,
)

// Its application-error encoder throws, for the server's internal-error path.
let throwingErrorCodec =
  Endpoint.get(
    "/throwing-error-codec",
    ~params=Codec.unit,
    ~response=accountCodec,
  )->Endpoint.withErrors(
    {...accountErrorCodec, encode: _ => JsError.throwWithMessage("secret internal detail")},
    ~status=_ => 404,
  )
