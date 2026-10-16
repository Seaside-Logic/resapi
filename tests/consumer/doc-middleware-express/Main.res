// Runs the Express version of site/content/middleware.md on a free port: the profile endpoint behind bearer-token
// middleware, called over HTTP with the typed client.
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
  let (profileServer, profileUrl) = await start(ProfileServer.app)
  let profileClient = (~token=?) =>
    Client.make(
      ~baseUrl=profileUrl,
      ~headers=token->Option.mapOr(dict{}, token => dict{"authorization": `Bearer ${token}`}),
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
  profileServer->ResApiExpress.Router.close
  Console.log("ok - middleware example (Express)")
}

main()->ignore
