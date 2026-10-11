// Runs README.md's examples: its Hono App called in-process, and its ExpressApp on a free port, each
// through a client like its AccountClient.
open ResApi
open Check

@module("node:events")
external once: (ResApiExpress.Router.server, string) => promise<unit> = "once"
@send external address: ResApiExpress.Router.server => {"port": int} = "address"

let checkAccounts = async (client, name) => {
  let found = await client->Client.call(AccountApi.getAccount, ~params={id: "acct_123"})
  check(
    switch found {
    | Ok({name: "Savings"}) => true
    | _ => false
    },
    `the README's account (${name})`,
  )
  let missing = await client->Client.call(AccountApi.getAccount, ~params={id: "nope"})
  check(
    switch missing {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    `the README's NotFound (${name})`,
  )
}

let main = async () => {
  await checkAccounts(
    Client.make(~baseUrl="http://app.test", ~fetch=request =>
      App.app->ResApiHono.Router.fetch(request, ())
    ),
    "Hono",
  )

  let server = ExpressApp.app->ResApiExpress.Router.listen(0, () => ())
  await once(server, "listening")
  await checkAccounts(
    Client.make(~baseUrl=`http://localhost:${(server->address)["port"]->Int.toString}`),
    "Express",
  )
  server->ResApiExpress.Router.close
  Console.log("ok - README examples")
}

main()->ignore
