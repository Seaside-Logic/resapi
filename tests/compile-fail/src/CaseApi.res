// Contracts with hand-written codecs, shared by the compile-fail cases. Core only: no Sury, no server.
open ResApi

type params = {id: string}
type account = {id: string, name: string}
type newAccount = {name: string}

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

let getAccount = Endpoint.get("/accounts/:id", ~params=paramsCodec, ~response=accountCodec)

let createAccount = Endpoint.post(
  "/accounts",
  ~params=Codec.unit,
  ~body=newAccountCodec,
  ~response=accountCodec,
)
