// Runs docs/express.md's App on a free port and calls it over HTTP with the typed client.
open ResApi
open Check

@module("node:events")
external once: (ResApiExpress.Router.server, string) => promise<unit> = "once"
@send external address: ResApiExpress.Router.server => {"port": int} = "address"

let main = async () => {
  let server = App.app->ResApiExpress.Router.listen(0, () => ())
  await once(server, "listening")
  let client = Client.make(~baseUrl=`http://localhost:${(server->address)["port"]->Int.toString}`)

  let created = await client->Client.callWithBody(
    NoteApi.createNote,
    ~params=(),
    ~body={text: "hi"},
  )
  let id = switch created {
  | Ok(note) => note.id
  | _ => JsError.throwWithMessage("check failed: create")
  }
  let found = await client->Client.call(NoteApi.getNote, ~params={id: id})
  check(found == Ok({id, text: "hi"}), "get")
  let missing = await client->Client.call(NoteApi.getNote, ~params={id: "nope"})
  check(
    switch missing {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    "NotFound",
  )
  server->ResApiExpress.Router.close
  Console.log("ok - express guide example")
}

main()->ignore
