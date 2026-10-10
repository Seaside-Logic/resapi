// Core, Sury and Hono: a typed endpoint served by the router, called in-process by the typed client.
open ResApi
open ResApiHono
open Check

let app: Router.t<unit> =
  Router.make()
  ->Router.register(
    Api.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
      params.id == "a1" ? Ok({id: "a1", name: "Ann"}) : Error(NotFound)
    ),
  )
  ->Router.register(
    Api.createAccount->EndpointHandler.make(async (_ctx, {body}) => Ok({
      id: "new",
      name: body.name,
    })),
  )

let client = Client.make(~baseUrl="http://app.test", ~fetch=request =>
  app->Router.fetch(request, ())
)

let main = async () => {
  let ok = await client->Client.call(Api.getAccount, ~params={id: "a1"})
  check(ok == Ok({id: "a1", name: "Ann"}), "typed GET")

  let notFound = await client->Client.call(Api.getAccount, ~params={id: "x"})
  check(
    switch notFound {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    "typed application error",
  )

  let created = await client->Client.callWithBody(Api.createAccount, ~params=(), ~body={name: "Bo"})
  check(created == Ok({id: "new", name: "Bo"}), "typed POST")

  let bad = await app->Router.fetch(
    Fetch.Request.make("http://app.test/accounts", ~init={method: "POST", body: `{"name":1}`}),
    (),
  )
  check(bad->Fetch.Response.status == 400, "invalid body is a 400")
  Console.log("ok - hono")
}

main()->ignore
