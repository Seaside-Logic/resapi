// Servers for tests/auth.test.mjs (Express): auth as middleware, with typed keys.
open ResApi
open ResApiExpress

type user = {name: string}

let userKey: Key.t<user> = Key.make("user")

let requireUser: Router.middleware = (req, res, next) =>
  switch req->Req.header("x-user") {
  | None => res->Res.status(401)->Res.send("no user")
  | Some(name) =>
    req->Req.set(userKey, {name: name})
    next()
  }

// As Passport does: a plain `req.user` property, null when nobody is signed in.
@set external setUser: (Req.t, Nullable.t<user>) => unit = "user"
let passportLike: Router.middleware = (req, _res, next) => {
  req->setUser(
    switch req->Req.header("x-passport") {
    | Some(name) => Nullable.make({name: name})
    | None => Nullable.null
    },
  )
  next()
}

let app =
  Router.make()
  ->Router.use(~path="/accounts", requireUser)
  ->Router.use(~path="/passport", passportLike)
  ->Router.register(
    TestApi.getAccount->EndpointHandler.make(async (req, {params}) => Ok({
      id: params.id,
      name: (req->Req.getOrThrow(userKey)).name,
    })),
  )
  ->Router.register(
    TestApi.createAccount->EndpointHandler.make(async (req, {body}) => Ok({
      id: "new",
      name: `${body.name} by ${(req->Req.getOrThrow(userKey)).name}`,
    })),
  )
  ->Router.get("/passport", async (req, res) =>
    res->Res.send(req->Req.get(userKey)->Option.mapOr("nobody", user => user.name))
  )
