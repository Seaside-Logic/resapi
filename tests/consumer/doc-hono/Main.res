// Runs docs/hono.md's App in-process with the typed client: auth middleware, typed endpoints, the body
// limit and notFound.
open ResApi
open Check

let clientWith = (~token=?) =>
  Client.make(
    ~baseUrl="http://localhost",
    ~headers=token->Option.mapOr(dict{}, token => dict{"authorization": `Bearer ${token}`}),
    ~fetch=request => App.app->ResApiHono.Router.fetch(request, ()),
  )

let main = async () => {
  let ada = clientWith(~token="secret-token")

  check(
    switch await clientWith()->Client.callWithBody(
      NoteApi.createNote,
      ~params=(),
      ~body={text: "hi"},
    ) {
    | Error(Unauthorized({status: 401, reason: None})) => true
    | _ => false
    },
    "no token: Unauthorized without a reason",
  )
  check(
    switch await clientWith(~token="wrong")->Client.call(NoteApi.getNote, ~params={id: "note_1"}) {
    | Error(Unauthorized({status: 401, reason: Some("invalid_token")})) => true
    | _ => false
    },
    "wrong token: Unauthorized with its reason",
  )

  let created = await ada->Client.callWithBody(NoteApi.createNote, ~params=(), ~body={text: "hi"})
  let note = switch created {
  | Ok({author: "Ada", _} as note) => note
  | _ => JsError.throwWithMessage("check failed: create, with the author from the key")
  }
  check((await ada->Client.call(NoteApi.getNote, ~params={id: note.id})) == Ok(note), "get")
  check(
    switch await ada->Client.call(NoteApi.getNote, ~params={id: "nope"}) {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    "NotFound",
  )
  check(
    switch await ada->Client.callWithBody(
      NoteApi.createNote,
      ~params=(),
      ~body={text: String.repeat("x", 2000)},
    ) {
    | Error(UnexpectedStatus({status: 413, _})) => true
    | _ => false
    },
    "an oversized body: bodyLimit's 413",
  )

  let missing = await App.app->ResApiHono.Router.fetch(
    Fetch.Request.fromURL("http://localhost/nope"),
    (),
  )
  check(
    missing.status == 404 && (await missing->Fetch.Response.text) == `{"error":"not_found"}`,
    "notFound",
  )
  Console.log("ok - hono guide example")
}

main()->ignore
