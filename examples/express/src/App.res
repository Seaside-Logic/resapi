open ResApiExpress

let app =
  Router.make()
  ->Router.use(~path="/protected", Auth.bearer)
  ->Router.get("/health", async (_req, res) =>
    res->Res.json(JSON.Encode.object(dict{"status": JSON.Encode.string("ok")}))
  )
  ->Router.get("/protected", async (_req, res) => res->Res.send("secret"))
  ->Router.register(
    AccountApi.getAccount->EndpointHandler.make(async (_req, {params}) =>
      switch AccountStore.get(params.id) {
      | Some(account) => Ok(account)
      | None => Error(NotFound)
      }
    ),
  )
  ->Router.register(
    AccountApi.createAccount->EndpointHandler.make(async (_req, {body}) => Ok(
      AccountStore.create(body),
    )),
  )
