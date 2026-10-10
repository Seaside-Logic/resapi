// Servers for tests/express.test.mjs: the Express adapter's own edges. The shared pipeline is covered on Hono.
open ResApiExpress

@module("express") external jsonParser: unit => Router.middleware = "json"

let accounts = dict{
  "a1": ({id: "a1", name: "Ann"}: TestApi.account),
  "a/b c": {id: "a/b c", name: "Slashed"},
}

let createAccount = TestApi.createAccount->EndpointHandler.make(async (_req, {body}) => Ok({
  id: "new",
  name: body.name,
}))

let app =
  Router.make()
  ->Router.get("/hello/:name", async (req, res) =>
    res->Res.send(`Hello, ${req->Req.params->Dict.getUnsafe("name")}!`)
  )
  ->Router.get("/throws", async (_req, _res) => throw(Not_found))
  ->Router.get("/send-then-throw", async (_req, res) => {
    res->Res.send("sent")
    throw(Not_found)
  })
  ->Router.use(~path="/middleware-throws", (_req, _res, _next) => throw(Failure("boom")))
  ->Router.get("/middleware-throws", async (_req, res) => res->Res.send("should not run"))
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (_req, {params}) =>
      switch (params.id, accounts->Dict.get(params.id)) {
      | ("secret", _) => Error(TestApi.AccessDenied)
      | (_, Some(account)) => Ok(account)
      | (_, None) => Error(NotFound)
      }
    ),
  )
  ->Router.register(createAccount)
  ->Router.register(
    TestApi.addMember->EndpointHandler.make(async (_req, {params, body}) => Ok({
      id: `${params.org}/${params.member->Int.toString}`,
      name: body.name,
    })),
  )
  ->Router.register(
    TestApi.brokenEncoder->EndpointHandler.make(async (_req, _) => Ok({id: "x", name: "x"})),
  )

// An app that parses JSON itself before the typed endpoint runs.
let jsonApp = Router.make()->Router.use(jsonParser())->Router.register(createAccount)

// Request-scoped state, as an app would bind it: Express has no typed slot, so this is a fixture-only field.
@set external setUser: (Req.t, string) => unit = "resapiUser"
@get external user: Req.t => string = "resapiUser"

let requireUser: Router.middleware = (req, res, next) =>
  switch req->Req.header("x-user") {
  | None => res->Res.status(401)->Res.send("Unauthorized")
  | Some(name) =>
    req->setUser(name)
    res->Res.setHeader("x-powered-by", "resAPI")->ignore
    next()
  }

// Native middleware in front of a typed endpoint.
let guardedApp =
  Router.make()
  ->Router.use(requireUser)
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (req, {params}) => Ok({
      id: params.id,
      name: req->user,
    })),
  )
