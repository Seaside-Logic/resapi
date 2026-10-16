// Runs the Hono version of site/content/middleware.md in-process: the profile endpoint behind bearer-token
// middleware.
open ResApi
open Check

let main = async () => {
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
  Console.log("ok - middleware example (Hono)")
}

main()->ignore
