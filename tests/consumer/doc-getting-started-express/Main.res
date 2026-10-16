// Runs the Express version of docs/getting-started.md on a free port, as docs/testing.md shows, and calls it
// over HTTP with the typed client: create an account, then read it.
open ResApi
open Check

@module("node:events")
external once: (ResApiExpress.Router.server, string) => promise<unit> = "once"
@send external address: ResApiExpress.Router.server => {"port": int} = "address"

let start = async app => {
  let server = app->ResApiExpress.Router.listen(0, () => ())
  await once(server, "listening")
  (server, `http://localhost:${(server->address)["port"]->Int.toString}`)
}

let main = async () => {
  let (server, baseUrl) = await start(App.app)
  let client = Client.make(~baseUrl)

  let created = await client->Client.callWithBody(
    AccountApi.createAccount,
    ~params=(),
    ~body={name: "Travel", balance: 12.5},
  )
  check(
    switch created {
    | Ok({id: "acct_1", name: "Travel"}) => true
    | _ => false
    },
    "create",
  )
  let found = await client->Client.call(AccountApi.getAccount, ~params={id: "acct_1"})
  check(
    switch found {
    | Ok({balance: 12.5}) => true
    | _ => false
    },
    "get",
  )
  let missing = await client->Client.call(AccountApi.getAccount, ~params={id: "nope"})
  check(
    switch missing {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    "NotFound",
  )
  server->ResApiExpress.Router.close

  Console.log("ok - getting-started example (Express)")
}

main()->ignore
