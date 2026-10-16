// Runs the Hono version of site/content/getting-started.md in-process, as site/content/testing.md shows: create an account,
// then read it.
open ResApi
open Check

let client = Client.make(~baseUrl="http://localhost", ~fetch=request =>
  App.app->ResApiHono.Router.fetch(request, ())
)

let main = async () => {
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
    | Error(Application({error: NotFound})) => true
    | _ => false
    },
    "NotFound",
  )
  Console.log("ok - getting-started example (Hono)")
}

main()->ignore
