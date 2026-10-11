// Server for tests/server.test.mjs: simple routes and typed endpoints on one router, with no middleware.
open ResApi
open ResApiHono

let accounts = dict{
  "a1": ({id: "a1", name: "Ann"}: TestApi.account),
  "a/b c": {id: "a/b c", name: "Slashed"},
}

let app: Router.t<unit> =
  Router.make()
  ->Router.get("/health", async _ctx =>
    Fetch.Response.jsonR(~data=JSON.Encode.object(dict{"status": JSON.Encode.string("ok")}))
  )
  ->Router.get("/hello/:name", async ctx =>
    Fetch.Response.fromString(`Hello, ${ctx->Context.param("name")}!`)
  )
  ->Router.get("/throws", async _ctx => throw(Not_found))
  ->Router.post("/echo", async ctx => Fetch.Response.fromString(await ctx->Context.text))
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      switch (params.id, accounts->Dict.get(params.id)) {
      | ("secret", _) => Error(TestApi.AccessDenied)
      | (_, Some(account)) => Ok(account)
      | (_, None) => Error(NotFound)
      }
    ),
  )
  ->Router.register(
    TestApi.createAccount->EndpointHandler.make(async (_ctx, {body}) => Ok({
      id: "new",
      name: body.name,
    })),
  )
  ->Router.register(
    TestApi.addMember->EndpointHandler.make(async (_ctx, {params, body}) => Ok({
      id: `${params.org}/${params.member->Int.toString}`,
      name: body.name,
    })),
  )
  ->Router.register(
    TestApi.badErrorStatus->EndpointHandler.make(async (_ctx, _) => Error(NotFound)),
  )
  ->Router.register(
    TestApi.brokenEncoder->EndpointHandler.make(async (_ctx, _) => Ok({id: "x", name: "x"})),
  )
  ->Router.register(
    TestApi.throwingBody->EndpointHandler.make(async (_ctx, _) => Ok({id: "x", name: "x"})),
  )
  ->Router.register(
    TestApi.throwingErrorCodec->EndpointHandler.make(async (_ctx, _) => Error(NotFound)),
  )
  // The handler rejects with a raw ReScript exception, not a JS Error.
  ->Router.register(TestApi.getMember->EndpointHandler.make(async (_ctx, _) => throw(Not_found)))
