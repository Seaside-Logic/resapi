// Server for tests/server.test.mjs: simple routes and typed endpoints on one router, with no middleware.
open ResApi
open ResApiHono

let accounts = dict{"a1": ({id: "a1", name: "Ann"}: TestApi.account)}

let app: Router.t<unit> =
  Router.make()
  ->Router.get("/health", async _ctx =>
    Fetch.Response.json(JSON.Encode.object(dict{"status": JSON.Encode.string("ok")}))
  )
  ->Router.get("/hello/:name", async ctx => Fetch.Response.text(`Hello, ${ctx->Context.param("name")}!`))
  ->Router.get("/throws", async _ctx => throw(Not_found))
  ->Router.post("/echo", async ctx => Fetch.Response.text(await ctx->Context.text))
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      switch accounts->Dict.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(EndpointHandler.notFound(`No account ${params.id}`))
      }
    ),
  )
  ->Router.register(
    TestApi.createAccount->EndpointHandler.make(async (_ctx, {body}) => Ok({id: "new", name: body.name})),
  )
  ->Router.register(
    TestApi.addMember->EndpointHandler.make(async (_ctx, {params, body}) =>
      Ok({id: `${params.org}/${params.member->Int.toString}`, name: body.name})
    ),
  )
  ->Router.register(
    TestApi.brokenEncoder->EndpointHandler.make(async (_ctx, _) => Ok({id: "x", name: "x"})),
  )
