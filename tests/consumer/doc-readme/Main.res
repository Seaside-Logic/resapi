// Runs README.md's example: its App, called in-process through a client like its AccountClient.
open ResApi
open Check

let client = Client.make(~baseUrl="http://app.test", ~fetch=request =>
  App.app->ResApiHono.Router.fetch(request, ())
)

let main = async () => {
  let found = await client->Client.call(AccountApi.getAccount, ~params={id: "acct_123"})
  check(
    switch found {
    | Ok({name: "Savings"}) => true
    | _ => false
    },
    "the README's account",
  )
  let missing = await client->Client.call(AccountApi.getAccount, ~params={id: "nope"})
  check(
    switch missing {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    "the README's NotFound",
  )
  Console.log("ok - README example")
}

main()->ignore
