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
  ->Router.get("/health", async _ctx => Fetch.Response.text("ok"))
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (_ctx, {params}) => Ok({id: params.id, name: "n"})),
  )
