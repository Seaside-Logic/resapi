open ResApi
open ResApiHono

@module("hono/logger") external logger: unit => Router.middleware<'env> = "logger"

let app =
  Router.make()
  ->Router.use(logger())
  ->Router.use(~path="/protected", Auth.bearer)
  ->Router.get("/health", async _ctx =>
    Fetch.Response.jsonR(~data=JSON.Encode.object(dict{"status": JSON.Encode.string("ok")}))
  )
  ->Router.get("/protected", async _ctx => Fetch.Response.fromString("secret"))
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      switch AccountStore.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )
  ->Router.register(
    AccountApi.createAccount->EndpointHandler.make(async (_ctx, {body}) => Ok(
      AccountStore.create(body),
    )),
  )
