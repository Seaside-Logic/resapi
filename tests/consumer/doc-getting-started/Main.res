// Runs docs/getting-started.md's App in-process, as its section 7 shows: create an account, then read it.
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
  // Section 6: the profile endpoint behind bearer-token middleware.
  let profileClient = (~token=?) =>
    Client.make(
      ~baseUrl="http://localhost",
      ~headers=token->Option.mapOr(dict{}, token => dict{"authorization": `Bearer ${token}`}),
      ~fetch=request => ProfileServer.app->ResApiHono.Router.fetch(request, ()),
    )
  check(
    switch await profileClient()->Client.call(ProfileApi.getProfile, ~params=()) {
    | Error(Unauthorized({status: 401, reason: None})) => true
    | _ => false
    },
    "no token: Unauthorized without a reason",
  )
  check(
    switch await profileClient(~token="wrong")->Client.call(ProfileApi.getProfile, ~params=()) {
    | Error(Unauthorized({status: 401, reason: Some("invalid_token")})) => true
    | _ => false
    },
    "wrong token: Unauthorized with its reason",
  )
  check(
    (await profileClient(~token="secret-token")->Client.call(ProfileApi.getProfile, ~params=())) ==
      Ok({name: "Ada"}),
    "right token: the user reaches the handler",
  )
  Console.log("ok - getting-started example")
}

main()->ignore
