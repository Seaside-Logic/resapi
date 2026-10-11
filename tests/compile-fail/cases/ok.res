// expect: compiles
// Control: proves the harness compiles valid code, so the failures below are real.
// Contracts import into plain code, their codec types are inferred, and a server can handle them.
open ResApi
open ResApiHono
let accountName = json => TestApi.getAccount.responseCodec.decode(json)->Result.map(a => a.name)
let paramsJson = TestApi.getAccount.paramsCodec.encode({id: "acct_123"})
let bodyJson = TestApi.createAccount.bodyCodec.encode({name: "n"})
let app: Router.t<unit> =
  Router.make()
  ->Router.get("/health", async _ctx => Fetch.Response.fromString("ok"))
  ->Router.register(
    TestApi.createAccount->EndpointHandler.make(async (_ctx, {body}) => Ok({id: "new", name: body.name})),
  )
let describe = async client =>
  switch await client->Client.call(TestApi.getAccount, ~params={id: "a1"}) {
  | Ok(account) => account.name
  | Error(Application({error: NotFound})) => "not found"
  | Error(Application({error: AccessDenied, status})) => `denied (${status->Int.toString})`
  | Error(Network(_) | Aborted | Unauthorized(_) | UnexpectedStatus(_) | InvalidResponse(_)) =>
    "failed"
  }
let typedErrorRoute: EndpointHandler.route<unit> = TestApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
  params.id == "a1" ? Ok({id: "a1", name: "n"}) : Error(NotFound)
)
