// Core alone, with a hand-written codec: no Sury and no server adapter installed.
open ResApi
open Check

type account = {id: string, name: string}

let accountCodec: Codec.t<account> = {
  decode: json =>
    switch json {
    | Object(d) =>
      switch (d->Dict.get("id"), d->Dict.get("name")) {
      | (Some(String(id)), Some(String(name))) => Ok({id, name})
      | _ => Error({path: [], message: "Expected an account"})
      }
    | _ => Error({path: [], message: "Expected an object"})
    },
  encode: a => JSON.Object(dict{"id": JSON.String(a.id), "name": JSON.String(a.name)}),
}

let me = Endpoint.get("/me", ~params=Codec.unit, ~response=accountCodec)

let client = body =>
  Client.make(~baseUrl="https://api.test", ~fetch=async _request => Fetch.Response.fromString(body))

let main = async () => {
  let ok = await client(`{"id":"a1","name":"Ann"}`)->Client.call(me, ~params=())
  check(ok == Ok({id: "a1", name: "Ann"}), "Ok response decodes")
  let invalid = await client(`[]`)->Client.call(me, ~params=())
  check(
    switch invalid {
    | Error(InvalidResponse(_)) => true
    | _ => false
    },
    "invalid response",
  )
  Console.log("ok - handwritten")
}

main()->ignore
